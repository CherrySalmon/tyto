# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/submissions'
require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../responses/policy_wrapper'
require_relative '../application_operation'

module Tyto
  module Service
    module Submissions
      # Service: Create or overwrite a student's submission for an assignment.
      # Enforces late resubmit policy (domain rule #3):
      #   - First-time late submissions always accepted
      #   - Resubmission after due_at blocked when allow_late_resubmit is false
      class CreateSubmission < ApplicationOperation
        def initialize(submissions_repo: Repository::Submissions.new,
                       assignments_repo: Repository::Assignments.new,
                       courses_repo: Repository::Courses.new)
          @submissions_repo = submissions_repo
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, assignment_id:, submission_data:)
          step validate_and_load(requestor:, course_id:, assignment_id:)
          entries = step validate_entries(submission_data)
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

        def validate_entries(data)
          entries_data = data['entries']
          return Failure(bad_request('Submission entries are required')) unless entries_data.is_a?(Array) && !entries_data.empty?

          entries = entries_data.map do |entry|
            req_id = entry['requirement_id']&.to_i
            return Failure(bad_request('Invalid requirement ID')) unless req_id&.positive?

            requirement = @assignment.submission_requirements&.find(req_id)
            return Failure(bad_request("Requirement #{req_id} not found for this assignment")) unless requirement

            content = entry['content']
            return Failure(bad_request('Content is required for each entry')) if content.nil? || content.to_s.strip.empty?

            if requirement.submission_format == 'file'
              step validate_file_entry(entry, requirement)
            end

            build_entry(entry, req_id)
          end

          Success(entries)
        end

        def validate_file_entry(entry, requirement)
          filename = entry['filename']
          return Failure(bad_request('Filename is required for file uploads')) if filename.nil? || filename.to_s.strip.empty?

          file_size = entry['file_size']&.to_i
          if file_size && file_size > 10_485_760
            return Failure(bad_request('File size exceeds 10 MB limit'))
          end

          if requirement.allowed_types && !requirement.allowed_types.empty?
            extension = File.extname(filename).delete_prefix('.').downcase
            allowed = requirement.allowed_types.split(',').map { |t| t.strip.downcase }
            unless allowed.include?(extension)
              return Failure(bad_request("File type '#{extension}' not allowed. Allowed: #{allowed.join(', ')}"))
            end
          end

          Success(true)
        end

        def build_entry(entry, requirement_id)
          Domain::Assignments::Entities::RequirementUpload.new(
            id: nil,
            submission_id: 0,
            requirement_id:,
            content: entry['content'],
            filename: entry['filename'],
            content_type: entry['content_type'],
            file_size: entry['file_size']&.to_i,
            created_at: nil,
            updated_at: nil
          )
        end

        def persist(entries)
          if @existing_submission
            # Overwrite: update submitted_at and upsert entries
            updated = @existing_submission.new(submitted_at: Time.now.utc)
            @submissions_repo.update(updated)
            result = @submissions_repo.upsert_entries(@existing_submission.id, entries)
          else
            # Create new submission
            entity = Domain::Assignments::Entities::Submission.new(
              id: nil,
              assignment_id: @assignment.id,
              account_id: @requestor.account_id,
              submitted_at: Time.now.utc,
              created_at: nil,
              updated_at: nil
            )
            result = @submissions_repo.create_with_entries(entity, entries)
          end

          Success(result)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def find_enrollment
          @courses_repo.find_enrollment(account_id: @requestor.account_id, course_id: @course_id)
        end
      end
    end
  end
end
