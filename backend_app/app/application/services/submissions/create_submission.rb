# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/submissions'
require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../infrastructure/file_storage/build_gateway'
require_relative '../../../infrastructure/file_storage/limits'
require_relative '../../../infrastructure/file_storage/submission_mapper'
require_relative '../../responses/policy_wrapper'
require_relative '../application_operation'

module Tyto
  module Service
    module Submissions
      # Service: Create or overwrite a student's submission for an assignment.
      #
      # For file-type entries the S3 key is reconstructed server-side from the
      # authenticated account_id and HEAD-checked against storage; client-supplied
      # `content` is ignored so a student cannot reference another student's key.
      # URL-type entries bypass storage — `content` is the raw URL string.
      #
      # On resubmit with a changed extension the old key is best-effort deleted
      # outside the DB transaction so a storage blip cannot roll back a valid
      # submission; same-extension resubmits rely on the storage backend's
      # overwrite-at-same-key semantics.
      #
      # Late resubmit policy (domain rule #3): first-time late submissions are
      # always accepted; resubmission after due_at is blocked when
      # `allow_late_resubmit` is false, regardless of whether the existing
      # submission was on-time.
      class CreateSubmission < ApplicationOperation
        def initialize(submissions_repo: Repository::Submissions.new,
                       assignments_repo: Repository::Assignments.new,
                       courses_repo: Repository::Courses.new,
                       gateway: Tyto::FileStorage.build_gateway)
          @submissions_repo = submissions_repo
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
          @gateway = gateway
          super()
        end

        def call(requestor:, course_id:, assignment_id:, submission_data:)
          step validate_and_load(requestor:, course_id:, assignment_id:)
          entries = step build_entries(submission_data)
          submission = step persist(entries)

          created(Response::PolicyWrapper.new(submission, policies: @policy.summary))
        end

        private

        def validate_and_load(requestor:, course_id:, assignment_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?
          return Failure(not_found('Course not found')) unless Tyto::Course[@course_id]

          @requestor = requestor
          @enrollment = find_enrollment
          @policy = Policy::Submission.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to submit')) unless @policy.can_submit?

          load_assignment(assignment_id)
        end

        def load_assignment(assignment_id)
          @assignment = @assignments_repo.find_with_requirements(assignment_id.to_i)
          return Failure(not_found('Assignment not found')) unless @assignment
          return Failure(not_found('Assignment not found')) unless @assignment.course_id == @course_id
          return Failure(bad_request('Assignment is not published')) unless @assignment.status == 'published'

          check_late_resubmit
        end

        def check_late_resubmit
          @existing_submission = @submissions_repo.find_by_account_assignment(
            @requestor.account_id, @assignment.id
          )

          if @existing_submission && past_due? && !@assignment.allow_late_resubmit
            return Failure(forbidden('Late resubmission is not allowed for this assignment'))
          end

          Success(true)
        end

        def past_due?
          @assignment.due_at && Time.now.utc > @assignment.due_at
        end

        def build_entries(data)
          entries_data = data['entries']
          return Failure(bad_request('Submission entries are required')) unless entries_data.is_a?(Array) && !entries_data.empty?

          entries = entries_data.map do |entry|
            req_id = entry['requirement_id']&.to_i
            return Failure(bad_request('Invalid requirement ID')) unless req_id&.positive?

            requirement = @assignment.submission_requirements&.find(req_id)
            return Failure(bad_request("Requirement #{req_id} not found for this assignment")) unless requirement

            if requirement.submission_format == 'file'
              step build_file_entry(entry, requirement)
            else
              step build_url_entry(entry, requirement)
            end
          end

          Success(entries)
        end

        def build_file_entry(entry, requirement)
          filename = entry['filename']
          return Failure(bad_request('Filename is required for file uploads')) if filename.nil? || filename.to_s.strip.empty?

          step validate_file_size(entry)
          step validate_file_extension(filename, requirement)
          key = step reconstruct_and_verify_key(filename, requirement)

          # Persist the underlying string — the entity stores `content` as
          # a String (it's polymorphic across file keys and URL strings).
          Success(build_upload(requirement.id, key.to_s, entry))
        end

        def build_url_entry(entry, requirement)
          content = entry['content']
          return Failure(bad_request('Content is required for each entry')) if content.nil? || content.to_s.strip.empty?

          Success(build_upload(requirement.id, content, entry))
        end

        def validate_file_size(entry)
          file_size = entry['file_size']&.to_i
          return Success(true) unless file_size && file_size > Tyto::FileStorage::MAX_SIZE_BYTES

          Failure(bad_request("File size exceeds #{Tyto::FileStorage::MAX_SIZE_BYTES} byte limit"))
        end

        def validate_file_extension(filename, requirement)
          return Success(true) if requirement.allowed_types.nil? || requirement.allowed_types.empty?

          extension = File.extname(filename).delete_prefix('.').downcase
          allowed = requirement.allowed_types.split(',').map { |t| t.strip.downcase }
          return Success(true) if allowed.include?(extension)

          Failure(bad_request("File type '#{extension}' not allowed. Allowed: #{allowed.join(', ')}"))
        end

        # Client-supplied `content` is never trusted — the key is rebuilt from
        # the authenticated account_id and that is what we persist and verify.
        def reconstruct_and_verify_key(filename, requirement)
          key = Tyto::FileStorage::SubmissionMapper.build_key(
            course_id: @course_id,
            assignment_id: @assignment.id,
            requirement_id: requirement.id,
            account_id: @requestor.account_id,
            filename:,
            submission_format: 'file'
          )

          return Success(key) if @gateway.head(key:).success?

          Failure(bad_request("Uploaded file not found in storage for requirement #{requirement.id}"))
        end

        # `filename` and `content_type` are stored as the client sent them and
        # treated as untrusted display metadata. Type enforcement comes from
        # the extension allowlist check above.
        def build_upload(requirement_id, content, entry)
          Domain::Assignments::Entities::RequirementUpload.new(
            id: nil,
            submission_id: 0,
            requirement_id:,
            content:,
            filename: entry['filename'],
            content_type: entry['content_type'],
            file_size: entry['file_size']&.to_i,
            created_at: nil,
            updated_at: nil
          )
        end

        def persist(entries)
          result = @existing_submission ? overwrite_existing(entries) : create_new(entries)
          Success(result)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def overwrite_existing(entries)
          old_keys = old_file_keys_by_requirement
          @submissions_repo.update(@existing_submission.new(submitted_at: Time.now.utc))
          result = @submissions_repo.upsert_entries(@existing_submission.id, entries)
          cleanup_orphaned_keys(entries, old_keys)
          result
        end

        def create_new(entries)
          entity = Domain::Assignments::Entities::Submission.new(
            id: nil,
            assignment_id: @assignment.id,
            account_id: @requestor.account_id,
            submitted_at: Time.now.utc,
            created_at: nil,
            updated_at: nil
          )
          @submissions_repo.create_with_entries(entity, entries)
        end

        def old_file_keys_by_requirement
          loaded = @submissions_repo.find_with_entries(@existing_submission.id)
          return {} unless loaded&.requirement_uploads

          loaded.requirement_uploads.each_with_object({}) do |upload, hash|
            hash[upload.requirement_id] = upload.content
          end
        end

        # Runs outside the DB transaction so a storage-side failure cannot roll
        # back a valid submission — the resulting orphan is acceptable.
        def cleanup_orphaned_keys(new_entries, old_keys_by_req)
          new_entries.each do |entry|
            requirement = @assignment.submission_requirements&.find(entry.requirement_id)
            next unless requirement&.submission_format == 'file'

            old_key = old_keys_by_req[entry.requirement_id]
            next if old_key.nil? || old_key == entry.content

            safely_delete(old_key)
          end
        end

        def safely_delete(key_string)
          key = Tyto::FileStorage::StorageKey.try_from(key_string)
          return unless key # malformed string in DB — skip cleanup

          result = @gateway.delete(key:)
          return if result.success?

          warn("CreateSubmission: best-effort delete failed for #{key}: #{result.failure}")
        rescue StandardError => e
          warn("CreateSubmission: best-effort delete raised for #{key_string}: #{e.message}")
        end

        def find_enrollment
          @courses_repo.find_enrollment(account_id: @requestor.account_id, course_id: @course_id)
        end
      end
    end
  end
end
