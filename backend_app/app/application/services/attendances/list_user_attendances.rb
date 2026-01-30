# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/attendances'
require_relative '../application_operation'

module Todo
  module Service
    module Attendances
      # Service: List user's own attendances for a course
      # Returns Success(ApiResult) with list of attendances or Failure(ApiResult) with error
      class ListUserAttendances < ApplicationOperation
        def initialize(attendances_repo: Repository::Attendances.new)
          @attendances_repo = attendances_repo
          super()
        end

        def call(requestor:, course_id:)
          course_id = step validate_course_id(course_id)
          course = step verify_course_exists(course_id)
          step authorize(requestor, course, course_id)
          attendances = step fetch_user_attendances(requestor, course_id)

          ok(attendances)
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def verify_course_exists(course_id)
          course = Course.first(id: course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def authorize(requestor, course, course_id)
          course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id:).map do |ac|
            ac.role.name
          end
          policy = AttendancePolicy.new(requestor, course, course_roles)

          return Failure(forbidden('You have no access to view attendances')) unless policy.can_view?

          Success(true)
        end

        def fetch_user_attendances(requestor, course_id)
          account_id = requestor['account_id']
          attendances = @attendances_repo.find_by_account_course(account_id, course_id)
          Success(attendances)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
