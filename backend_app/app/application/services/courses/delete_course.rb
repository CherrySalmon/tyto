# frozen_string_literal: true

require_relative '../application_operation'

module Todo
  module Service
    module Courses
      # Service: Delete a course
      # Returns Success(ApiResult) or Failure(ApiResult) with error
      class DeleteCourse < ApplicationOperation
        def call(requestor:, course_id:)
          course_id = step validate_course_id(course_id)
          course = step find_course(course_id)
          step authorize(requestor, course, course_id)
          step delete_course(course)

          ok('Course deleted')
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

          return Failure(forbidden('You have no access to delete this course')) unless policy.can_delete?

          Success(true)
        end

        def delete_course(course)
          course.destroy
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
