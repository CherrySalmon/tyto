# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/attendances'
require_relative '../../../infrastructure/database/repositories/events'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../domain/attendance/entities/event_attendance_report'
require_relative '../application_operation'

module Tyto
  module Service
    module Attendances
      # Service: List enrolled students with attendance status for an event
      # Returns EventParticipantSummary domain entity with participants + policy summary
      # Returns Success(ApiResult) or Failure(ApiResult)
      class ListEventParticipants < ApplicationOperation
        def initialize(attendances_repo: Repository::Attendances.new,
                       events_repo: Repository::Events.new,
                       courses_repo: Repository::Courses.new)
          @attendances_repo = attendances_repo
          @events_repo = events_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, event_id:)
          course_id = step validate_id(course_id, 'course')
          event_id = step validate_id(event_id, 'event')
          step verify_course_exists(course_id)
          course = step authorize(requestor, course_id)
          step verify_event(course_id, event_id)
          attendances = step fetch_attendances(event_id)
          policies = build_policy_summary(requestor, course)

          ok(Domain::Attendance::Entities::EventAttendanceReport.new(
            enrollments: course.enrollments, attendances:, policies:
          ))
        end

        private

        def validate_id(id, label)
          parsed = id.to_i
          return Failure(bad_request("Invalid #{label} ID")) if parsed.zero?

          Success(parsed)
        end

        def verify_course_exists(course_id)
          course = Course.first(id: course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def authorize(requestor, course_id)
          course = @courses_repo.find_with_enrollments(course_id)
          policy = AttendanceManagementAuthorization.new(requestor, course)

          return Failure(forbidden('You do not have permission to view participants')) unless policy.can_view_all?

          Success(course)
        end

        def verify_event(course_id, event_id)
          event = @events_repo.find_id(event_id)
          return Failure(not_found('Event not found')) unless event
          return Failure(bad_request('Event does not belong to this course')) unless event.course_id == course_id

          Success(event)
        end

        def fetch_attendances(event_id)
          attendances = @attendances_repo.find_by_event(event_id)
          Success(attendances)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def build_policy_summary(requestor, course)
          AttendanceManagementAuthorization.new(requestor, course).summary
        end
      end
    end
  end
end
