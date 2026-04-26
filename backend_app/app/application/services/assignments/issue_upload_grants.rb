# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../infrastructure/file_storage/submission_mapper'
require_relative '../application_operation'

module Tyto
  module Service
    module Assignments
      # Service: Issue presigned upload grants for a student's file uploads (R-P10).
      #
      # An "upload grant" is a short-lived, scoped credential that authorizes a
      # single direct upload to storage — borrowing OAuth/IAM "grant" vocabulary
      # because the response is more than a URL: each entry contains the target
      # URL, the server-built S3 key, and a signed policy doc the client must
      # form-POST alongside the file.
      #
      # For each requested upload, the service:
      #   - authorizes the requestor via Policy::Submission#can_submit?
      #   - validates the target requirement (must belong to the assignment,
      #     submission_format must be 'file', filename extension must match
      #     allowed_types case-insensitively)
      #   - constructs the S3 key server-side via SubmissionMapper using the
      #     authenticated account_id (R-P2 — never trusts a body-supplied
      #     account_id or key)
      #   - asks the Gateway to presign a POST upload (R-P1) — the size cap is
      #     baked into the policy doc by the Gateway from MAX_SIZE_BYTES (R-P7)
      #
      # Returns an array of `{requirement_id, key, upload_url, fields}` entries
      # the frontend can use to multipart form-POST directly to the storage
      # backend (S3 in production, LocalGateway in dev/test).
      class IssueUploadGrants < ApplicationOperation
        def initialize(
          assignments_repo: Repository::Assignments.new,
          courses_repo: Repository::Courses.new,
          gateway: Tyto::FileStorage.build_gateway
        )
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
          @gateway = gateway
          super()
        end

        def call(requestor:, course_id:, assignment_id:, uploads:)
          step validate_and_authorize(requestor:, course_id:, assignment_id:)
          step validate_uploads_array(uploads)
          entries = step build_entries(uploads)

          created(entries)
        end

        private

        def validate_and_authorize(requestor:, course_id:, assignment_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?
          return Failure(not_found('Course not found')) unless Tyto::Course[@course_id]

          @requestor = requestor
          @enrollment = @courses_repo.find_enrollment(
            account_id: @requestor.account_id, course_id: @course_id
          )
          @policy = Policy::Submission.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to submit')) unless @policy.can_submit?

          load_assignment(assignment_id)
        end

        def load_assignment(assignment_id)
          @assignment = @assignments_repo.find_with_requirements(assignment_id.to_i)
          return Failure(not_found('Assignment not found')) unless @assignment
          return Failure(not_found('Assignment not found')) unless @assignment.course_id == @course_id
          return Failure(bad_request('Assignment is not published')) unless @assignment.status == 'published'

          Success(true)
        end

        def validate_uploads_array(uploads)
          return Failure(bad_request('Uploads are required')) unless uploads.is_a?(Array) && !uploads.empty?

          Success(true)
        end

        def build_entries(uploads)
          entries = uploads.map do |upload|
            requirement = step lookup_requirement(upload)
            filename = step validate_filename(upload)
            step validate_format(requirement)
            step validate_extension(requirement, filename)

            build_entry(requirement, filename)
          end

          Success(entries)
        end

        def lookup_requirement(upload)
          req_id = upload['requirement_id']&.to_i
          return Failure(bad_request('Invalid requirement ID')) unless req_id&.positive?

          requirement = @assignment.submission_requirements&.find(req_id)
          return Failure(bad_request("Requirement #{req_id} not found for this assignment")) unless requirement

          Success(requirement)
        end

        def validate_format(requirement)
          unless requirement.submission_format == 'file'
            return Failure(bad_request("Requirement #{requirement.id} does not accept file uploads"))
          end

          Success(true)
        end

        def validate_filename(upload)
          filename = upload['filename'].to_s
          return Failure(bad_request('Filename is required')) if filename.strip.empty?

          Success(filename)
        end

        def validate_extension(requirement, filename)
          extension = File.extname(filename).delete_prefix('.').downcase
          return Failure(bad_request("Filename '#{filename}' has no extension")) if extension.empty?

          allowed = parse_allowed(requirement.allowed_types)
          return Success(extension) if allowed.empty? || allowed.include?(extension)

          Failure(bad_request("File type '#{extension}' not allowed. Allowed: #{allowed.join(', ')}"))
        end

        def build_entry(requirement, filename)
          key = Tyto::FileStorage::SubmissionMapper.build_key(
            assignment_id: @assignment.id,
            requirement_id: requirement.id,
            account_id: @requestor.account_id,
            filename:,
            submission_format: requirement.submission_format
          )

          payload = step presign(key, requirement)

          {
            requirement_id: requirement.id,
            key:,
            upload_url: payload[:upload_url],
            fields: payload[:fields]
          }
        end

        def presign(key, requirement)
          result = @gateway.presign_upload(
            key:, allowed_extensions: parse_allowed(requirement.allowed_types)
          )
          return Failure(internal_error("Failed to presign upload: #{result.failure}")) unless result.success?

          Success(result.value!)
        end

        def parse_allowed(allowed_types)
          return [] if allowed_types.nil? || allowed_types.to_s.strip.empty?

          allowed_types.to_s.split(',').map { |t| t.strip.delete_prefix('.').downcase }.reject(&:empty?)
        end
      end
    end
  end
end
