# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Courses
      # Service: Get assignable roles for the requestor in a course
      # Returns Success(ApiResult) with list of role strings the requestor can assign,
      # or Failure(ApiResult) with error
      class GetAssignableRoles < ApplicationOperation
        def initialize(courses_repo: Repository::Courses.new)
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:)
          course_id = step validate_course_id(course_id)
          step find_course(course_id)
          enrollment = step authorize(requestor, course_id)
          roles = Policy::RoleAssignment.for_enrollment(enrollment.roles)

          ok(roles)
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def find_course(course_id)
          course = Course.first(id: course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def authorize(requestor, course_id)
          enrollment = @courses_repo.find_enrollment(account_id: requestor.account_id, course_id:)
          policy = Tyto::CoursePolicy.new(requestor, enrollment)

          return Failure(forbidden('You have no access to this course')) unless policy.can_view?

          Success(enrollment)
        end
      end
    end
  end
end
