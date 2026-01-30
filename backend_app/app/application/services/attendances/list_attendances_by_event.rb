# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/attendances'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Attendances
      # Service: List attendances for a specific event (for instructors/staff/owner)
      # Returns Success(ApiResult) with list of attendances or Failure(ApiResult) with error
      class ListAttendancesByEvent < ApplicationOperation
        def initialize(attendances_repo: Repository::Attendances.new, courses_repo: Repository::Courses.new)
          @attendances_repo = attendances_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, event_id:)
          course_id = step validate_course_id(course_id)
          event_id = step validate_event_id(event_id)
          step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          attendances = step fetch_attendances(course_id, event_id)

          ok(attendances)
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def validate_event_id(event_id)
          id = event_id.to_i
          return Failure(bad_request('Invalid event ID')) if id.zero?

          Success(id)
        end

        def verify_course_exists(course_id)
          course = Course.first(id: course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def authorize(requestor, course_id)
          enrollment = @courses_repo.find_enrollment(account_id: requestor.account_id, course_id:)
          policy = AttendancePolicy.new(requestor, enrollment)

          return Failure(forbidden('You have no access to view attendances')) unless policy.can_view_all?

          Success(true)
        end

        def fetch_attendances(course_id, event_id)
          # Filter by both course_id and event_id for proper scoping
          all_event_attendances = @attendances_repo.find_by_event(event_id)
          attendances = all_event_attendances.select { |a| a.course_id == course_id }
          Success(attendances)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
