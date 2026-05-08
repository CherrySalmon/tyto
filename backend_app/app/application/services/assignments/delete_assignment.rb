# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../infrastructure/database/repositories/submissions'
require_relative '../application_operation'

module Tyto
  module Service
    module Assignments
      # Service: Delete an assignment.
      # Authorization denies deletion once submissions exist (Policy::Assignment);
      # teaching staff should use the disabled lifecycle state instead.
      class DeleteAssignment < ApplicationOperation
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
          step delete

          ok('Assignment deleted')
        end

        private

        def validate_and_load(requestor:, course_id:, assignment_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?

          @requestor = requestor
          @enrollment = find_enrollment
          role_gate = Policy::Assignment.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to delete assignments')) unless role_gate.can_delete?

          step = load_assignment(assignment_id)
          return step if step.failure?

          authorize_against_submissions
        end

        def load_assignment(assignment_id)
          @assignment = @assignments_repo.find_id(assignment_id.to_i)
          return Failure(not_found('Assignment not found')) unless @assignment
          return Failure(not_found('Assignment not found')) unless @assignment.course_id == @course_id

          Success(true)
        end

        def authorize_against_submissions
          has_submissions = @submissions_repo.any_for_assignment?(@assignment.id)
          @policy = Policy::Assignment.new(@requestor, @enrollment, has_submissions: has_submissions)
          return Failure(forbidden('Cannot delete an assignment with submissions')) unless @policy.can_delete?

          Success(true)
        end

        def find_enrollment
          @courses_repo.find_enrollment(account_id: @requestor.account_id, course_id: @course_id)
        end

        def delete
          @assignments_repo.delete(@assignment.id)
          Success(true)
        end
      end
    end
  end
end
