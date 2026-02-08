# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/attendances'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../domain/attendance/entities/attendance_report'
require_relative '../application_operation'

module Tyto
  module Service
    module Attendances
      # Service: Generate attendance report for a course (for instructors/staff/owner)
      # Returns Success(ApiResult) with report hash or Failure(ApiResult) with error
      class GenerateReport < ApplicationOperation
        def initialize(attendances_repo: Repository::Attendances.new, courses_repo: Repository::Courses.new)
          @attendances_repo = attendances_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:)
          course_id = step validate_course_id(course_id)
          course = step fetch_course(course_id)
          step authorize(requestor, course_id)
          attendances = step fetch_attendances(course_id)
          report = Entity::AttendanceReport.new(course:, attendances:)

          ok(report)
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def fetch_course(course_id)
          course = @courses_repo.find_full(course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def authorize(requestor, course_id)
          enrollment = @courses_repo.find_enrollment(account_id: requestor.account_id, course_id:)
          policy = AttendanceAuthorization.new(requestor, enrollment)

          return Failure(forbidden('You have no access to generate report')) unless policy.can_view_all?

          Success(true)
        end

        def fetch_attendances(course_id)
          attendances = @attendances_repo.find_by_course(course_id)
          Success(attendances)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
