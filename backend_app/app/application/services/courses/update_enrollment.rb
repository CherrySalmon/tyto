# frozen_string_literal: true

require_relative '../application_operation'

module Tyto
  module Service
    module Courses
      # Service: Update a single enrollment for a course
      # Returns Success(ApiResult) or Failure(ApiResult) with error
      class UpdateEnrollment < ApplicationOperation
        def call(requestor:, course_id:, account_id:, enrolled_data:)
          course_id = step validate_course_id(course_id)
          account_id = step validate_account_id(account_id)
          course = step find_course(course_id)
          step authorize(requestor, course, course_id)
          step validate_enrolled_data(enrolled_data)
          step process_enrollment(course, account_id, enrolled_data)

          ok('Enrollment updated')
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def validate_account_id(account_id)
          id = account_id.to_i
          return Failure(bad_request('Invalid account ID')) if id.zero?

          Success(id)
        end

        def find_course(course_id)
          course = Course.first(id: course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def authorize(requestor, course, course_id)
          course_roles = AccountCourse.where(account_id: requestor.account_id, course_id:).map do |ac|
            ac.role.name
          end
          policy = CoursePolicy.new(requestor, course, course_roles)

          return Failure(forbidden('You have no access to update enrollments')) unless policy.can_update?

          Success(true)
        end

        def validate_enrolled_data(enrolled_data)
          return Failure(bad_request('Enrollment data is required')) if enrolled_data.nil?

          Success(enrolled_data)
        end

        def process_enrollment(course, account_id, enrolled_data)
          course.update_single_enrollment(account_id, enrolled_data)
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
