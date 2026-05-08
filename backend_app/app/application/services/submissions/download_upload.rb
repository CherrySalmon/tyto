# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/submissions'
require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../infrastructure/file_storage/build_gateway'
require_relative '../../../infrastructure/file_storage/storage_key'
require_relative '../application_operation'

module Tyto
  module Service
    module Submissions
      # Service: Issue a fresh presigned GET URL for a single upload on a
      # submission. The route 302-redirects to the URL — render-time presigning
      # would silently expire on long-open staff views, so each click mints
      # short-lived credentials.
      #
      # Resource-existence is validated before authorization so a missing
      # upload returns 404 regardless of whether the requestor would have
      # been authorized. A 403 is reserved for requestors who do exist in
      # the course context but cannot view the submission. URL-type uploads
      # have no storage and respond 404 — the raw URL in `content` is the
      # link, fetched directly.
      class DownloadUpload < ApplicationOperation
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

        def call(requestor:, course_id:, assignment_id:, submission_id:, upload_id:)
          step load_course(course_id)
          step load_assignment(assignment_id)
          step load_submission(submission_id)
          step load_upload(upload_id)
          step ensure_file_type
          step authorize(requestor)
          mint_url
        end

        private

        def load_course(course_id)
          @course_id = course_id.to_i
          return Failure(not_found('Course not found')) if @course_id.zero?
          return Failure(not_found('Course not found')) unless Tyto::Course[@course_id]

          Success(true)
        end

        def load_assignment(assignment_id)
          @assignment = @assignments_repo.find_with_requirements(assignment_id.to_i)
          return Failure(not_found('Assignment not found')) unless @assignment
          return Failure(not_found('Assignment not found')) unless @assignment.course_id == @course_id

          Success(true)
        end

        def load_submission(submission_id)
          @submission = @submissions_repo.find_with_entries(submission_id.to_i)
          return Failure(not_found('Submission not found')) unless @submission
          return Failure(not_found('Submission not found')) unless @submission.assignment_id == @assignment.id

          Success(true)
        end

        def load_upload(upload_id)
          uploads = @submission.requirement_uploads
          @upload = uploads&.find { |u| u.id == upload_id.to_i }
          return Failure(not_found('Upload not found')) unless @upload

          Success(true)
        end

        def ensure_file_type
          requirement = @assignment.submission_requirements&.find(@upload.requirement_id)
          return Failure(not_found('Upload has no downloadable file')) unless requirement&.submission_format == 'file'

          Success(true)
        end

        def authorize(requestor)
          @requestor = requestor
          @enrollment = @courses_repo.find_enrollment(
            account_id: requestor.account_id, course_id: @course_id
          )
          @policy = Policy::Submission.new(requestor, @enrollment)
          return Failure(forbidden('You are not authorized to view this submission')) unless @policy.can_view_own?

          unless @policy.can_view_all? || @submission.account_id == requestor.account_id
            return Failure(forbidden('You can only view your own submissions'))
          end

          Success(true)
        end

        def mint_url
          key = Tyto::FileStorage::StorageKey.try_from(@upload.content)
          return Failure(internal_error('Stored upload key is malformed')) unless key

          result = @gateway.presign_download(key:)
          return Failure(internal_error("Could not mint download URL: #{result.failure}")) if result.failure?

          ok(result.value![:download_url])
        end
      end
    end
  end
end
