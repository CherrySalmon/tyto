# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Assignments
      # Service: Publish a draft assignment (draft → published transition)
      class PublishAssignment < ApplicationOperation
        def initialize(assignments_repo: Repository::Assignments.new,
                       courses_repo: Repository::Courses.new)
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, assignment_id:)
          step validate_and_load(requestor:, course_id:, assignment_id:)
          step publish

          ok('Assignment published')
        end

        private

        def validate_and_load(requestor:, course_id:, assignment_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?

          @requestor = requestor
          @enrollment = find_enrollment
          @policy = AssignmentPolicy.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to publish assignments')) unless @policy.can_publish?

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

        def publish
          unless @assignment.status == 'draft'
            return Failure(bad_request('Only draft assignments can be published'))
          end

          published = @assignment.new(status: 'published')
          @assignments_repo.update(published)
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
