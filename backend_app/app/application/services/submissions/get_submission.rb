# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/submissions'
require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../responses/policy_wrapper'
require_relative '../application_operation'

module Tyto
  module Service
    module Submissions
      # Service: Get a single submission with its entries.
      # Students can view their own; teaching staff can view any.
      class GetSubmission < ApplicationOperation
        def initialize(submissions_repo: Repository::Submissions.new,
                       assignments_repo: Repository::Assignments.new,
                       courses_repo: Repository::Courses.new)
          @submissions_repo = submissions_repo
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, assignment_id:, submission_id:)
          step validate_and_load(requestor:, course_id:, assignment_id:, submission_id:)

          ok(Response::PolicyWrapper.new(@submission, policies: @policy.summary))
        end

        private

        def validate_and_load(requestor:, course_id:, assignment_id:, submission_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?

          @requestor = requestor
          @enrollment = find_enrollment
          @policy = Policy::Submission.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to view submissions')) unless @policy.can_view_own?

          step load_assignment(assignment_id)
          load_submission(submission_id)
        end

        def load_assignment(assignment_id)
          @assignment = @assignments_repo.find_id(assignment_id.to_i)
          return Failure(not_found('Assignment not found')) unless @assignment
          return Failure(not_found('Assignment not found')) unless @assignment.course_id == @course_id

          Success(true)
        end

        def load_submission(submission_id)
          @submission = @submissions_repo.find_with_entries(submission_id.to_i)
          return Failure(not_found('Submission not found')) unless @submission
          return Failure(not_found('Submission not found')) unless @submission.assignment_id == @assignment.id

          # Students can only view their own
          unless @policy.can_view_all? || @submission.account_id == @requestor.account_id
            return Failure(forbidden('You can only view your own submissions'))
          end

          Success(true)
        end

        def find_enrollment
          @courses_repo.find_enrollment(account_id: @requestor.account_id, course_id: @course_id)
        end
      end
    end
  end
end
