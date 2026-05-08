# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../infrastructure/database/repositories/submissions'
require_relative '../../responses/policy_wrapper'
require_relative '../application_operation'

module Tyto
  module Service
    module Assignments
      # Service: Get a single assignment with its requirements
      # Teaching staff see all; students see only published.
      # The policy summary reflects whether the assignment has submissions,
      # so the frontend can gate unpublish/delete controls accordingly.
      class GetAssignment < ApplicationOperation
        def initialize(assignments_repo: Repository::Assignments.new,
                       courses_repo: Repository::Courses.new,
                       submissions_repo: Repository::Submissions.new)
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
          @submissions_repo = submissions_repo
          super()
        end

        def call(requestor:, course_id:, assignment_id:)
          step validate_and_load(requestor:, course_id:, assignment_id:)

          has_submissions = @submissions_repo.any_for_assignment?(@assignment.id)
          summary_policy = Policy::Assignment.new(@requestor, @enrollment, has_submissions: has_submissions)
          ok(Response::PolicyWrapper.new(@assignment, policies: summary_policy.summary))
        end

        private

        def validate_and_load(requestor:, course_id:, assignment_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?

          @requestor = requestor
          @enrollment = find_enrollment
          @policy = Policy::Assignment.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to view assignments')) unless @policy.can_view?

          load_assignment(assignment_id)
        end

        def load_assignment(assignment_id)
          @assignment = @assignments_repo.find_full(assignment_id.to_i)
          return Failure(not_found('Assignment not found')) unless @assignment
          return Failure(not_found('Assignment not found')) unless @assignment.course_id == @course_id
          unless @policy.can_view_drafts? || @assignment.status == 'published'
            return Failure(not_found('Assignment not found'))
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
