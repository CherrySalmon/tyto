# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Assignments
      # Service: Unpublish a published assignment (published → draft transition)
      # Only allowed when assignment has no submissions (placeholder for Slice 2)
      class UnpublishAssignment < ApplicationOperation
        def initialize(assignments_repo: Repository::Assignments.new,
                       courses_repo: Repository::Courses.new)
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
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
          @policy = Policy::Assignment.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to unpublish assignments')) unless @policy.can_unpublish?

          load_assignment(assignment_id)
        end

        def load_assignment(assignment_id)
          @assignment = @assignments_repo.find_id(assignment_id.to_i)
          return Failure(not_found('Assignment not found')) unless @assignment
          return Failure(not_found('Assignment not found')) unless @assignment.course_id == @course_id

          Success(true)
        end

        def find_enrollment
          @courses_repo.find_enrollment(account_id: @requestor.account_id, course_id: @course_id)
        end

        def unpublish
          unless @assignment.status == 'published'
            return Failure(bad_request('Only published assignments can be unpublished'))
          end

          if has_submissions?
            return Failure(bad_request('Cannot unpublish assignment with submissions'))
          end

          draft = @assignment.new(status: 'draft')
          @assignments_repo.update(draft)
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        # Placeholder: Slice 2 will check for actual submissions
        def has_submissions?
          false
        end
      end
    end
  end
end
