# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Todo
  module Service
    module Courses
      # Service: Get all enrollments for a course
      # Returns Success(ApiResult) with list of enrollments or Failure(ApiResult) with error
      class GetEnrollments < ApplicationOperation
        def initialize(courses_repo: Repository::Courses.new)
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:)
          course_id = step validate_course_id(course_id)
          course = step find_course(course_id)
          step authorize(requestor, course, course_id)
          enrollments = step fetch_enrollments(course_id)

          ok(enrollments)
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

        def authorize(requestor, course, course_id)
          course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id:).map do |ac|
            ac.role.name
          end
          policy = CoursePolicy.new(requestor, course, course_roles)

          return Failure(forbidden('You have no access to view enrollments')) unless policy.can_view?

          Success(true)
        end

        def fetch_enrollments(course_id)
          course_with_enrollments = @courses_repo.find_with_enrollments(course_id)
          return Failure(not_found('Course not found')) unless course_with_enrollments

          Success(course_with_enrollments.enrollments)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
