# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Courses
      # Service: Remove an enrollment from a course
      # Returns Success(ApiResult) or Failure(ApiResult) with error
      class RemoveEnrollment < ApplicationOperation
        def initialize(courses_repo: Repository::Courses.new)
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, account_id:)
          course_id = step validate_course_id(course_id)
          account_id = step validate_account_id(account_id)
          step find_course(course_id)
          step authorize(requestor, course_id)
          step remove_enrollment(course_id, account_id)

          ok('Enrollment removed')
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

        def authorize(requestor, course_id)
          enrollment = @courses_repo.find_enrollment(account_id: requestor.account_id, course_id:)
          policy = Tyto::CoursePolicy.new(requestor, enrollment)

          return Failure(forbidden('You have no access to remove enrollments')) unless policy.can_update?

          Success(true)
        end

        def remove_enrollment(course_id, account_id)
          # Remove all role assignments for this account in this course
          deleted = AccountCourse.where(account_id:, course_id:).delete

          return Failure(not_found('Enrollment not found')) if deleted.zero?

          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
