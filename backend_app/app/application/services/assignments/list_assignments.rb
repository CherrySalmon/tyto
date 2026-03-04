# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Assignments
      # Service: List assignments for a course
      # Teaching staff see all; students see only published
      class ListAssignments < ApplicationOperation
        def initialize(assignments_repo: Repository::Assignments.new,
                       courses_repo: Repository::Courses.new)
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:)
          step validate_and_load(requestor:, course_id:)
          assignments = step fetch_assignments

          ok(assignments)
        end

        private

        def validate_and_load(requestor:, course_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?

          @requestor = requestor
          @enrollment = find_enrollment
          @policy = AssignmentPolicy.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to view assignments')) unless @policy.can_view?

          Success(true)
        end

        def find_enrollment
          @courses_repo.find_enrollment(account_id: @requestor.account_id, course_id: @course_id)
        end

        def fetch_assignments
          assignments = if @policy.can_view_drafts?
                          @assignments_repo.find_by_course(@course_id)
                        else
                          @assignments_repo.find_by_course_and_status(@course_id, 'published')
                        end

          Success(assignments)
        end
      end
    end
  end
end
