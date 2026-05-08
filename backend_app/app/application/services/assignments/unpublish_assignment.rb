# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../infrastructure/database/repositories/submissions'
require_relative '../application_operation'

module Tyto
  module Service
    module Assignments
      # Service: Unpublish a published assignment (published → draft transition).
      # Authorization denies unpublishing when submissions exist (Policy::Assignment),
      # to avoid hiding work students have already submitted.
      class UnpublishAssignment < ApplicationOperation
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
          step unpublish

          ok('Assignment unpublished')
        end

        private

        def validate_and_load(requestor:, course_id:, assignment_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?

          @requestor = requestor
          @enrollment = find_enrollment
          # Role-only pre-check to avoid leaking existence to unauthorized callers.
          role_gate = Policy::Assignment.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to unpublish assignments')) unless role_gate.can_unpublish?

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
          return Failure(forbidden('Cannot unpublish an assignment with submissions')) unless @policy.can_unpublish?

          Success(true)
        end

        def find_enrollment
          @courses_repo.find_enrollment(account_id: @requestor.account_id, course_id: @course_id)
        end

        def unpublish
          unless @assignment.status == 'published'
            return Failure(bad_request('Only published assignments can be unpublished'))
          end

          draft = @assignment.new(status: 'draft')
          @assignments_repo.update(draft)
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
