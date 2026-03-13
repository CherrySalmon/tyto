# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/attendances'
require_relative '../../../infrastructure/database/repositories/events'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Attendances
      # Service: Instructor/staff toggles attendance for a student at an event
      # Bypasses geo-fence and time-window eligibility checks
      # Returns Success(ApiResult) or Failure(ApiResult)
      class UpdateParticipantAttendance < ApplicationOperation
        def initialize(attendances_repo: Repository::Attendances.new,
                       events_repo: Repository::Events.new,
                       courses_repo: Repository::Courses.new)
          @attendances_repo = attendances_repo
          @events_repo = events_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, event_id:, target_account_id:, attended:)
          course_id = step validate_id(course_id, 'course')
          event_id = step validate_id(event_id, 'event')
          target_account_id = step validate_id(target_account_id, 'account')
          step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          event = step verify_event(course_id, event_id)
          step verify_event_not_future(event)
          step verify_target_enrolled(target_account_id, course_id)
          step toggle_attendance(target_account_id, course_id, event_id, attended)

          ok('Attendance updated')
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

          return Failure(forbidden('You do not have permission to manage attendance')) unless policy.can_manage?

          Success(true)
        end

        def verify_event(course_id, event_id)
          event = @events_repo.find_id(event_id)
          return Failure(not_found('Event not found')) unless event
          return Failure(bad_request('Event does not belong to this course')) unless event.course_id == course_id

          Success(event)
        end

        def verify_event_not_future(event)
          return Failure(forbidden('Cannot manage attendance for a future event')) if event.upcoming?

          Success(true)
        end

        def verify_target_enrolled(target_account_id, course_id)
          enrollment = @courses_repo.find_enrollment(account_id: target_account_id, course_id:)
          return Failure(bad_request('Target account is not enrolled in this course')) unless enrollment&.student?

          Success(enrollment)
        end

        def toggle_attendance(account_id, course_id, event_id, attended)
          if attended
            create_attendance(account_id, course_id, event_id)
          else
            delete_attendance(account_id, event_id)
          end
        end

        def create_attendance(account_id, course_id, event_id)
          student_role = Role.first(name: 'student')
          entity = Domain::Attendance::Entities::Attendance.new(
            id: nil,
            account_id: account_id,
            course_id: course_id,
            event_id: event_id,
            role_id: student_role.id,
            name: 'Attendance (instructor override)',
            longitude: nil,
            latitude: nil,
            created_at: nil,
            updated_at: nil
          )
          @attendances_repo.create(entity)
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def delete_attendance(account_id, event_id)
          existing = @attendances_repo.find_by_account_event(account_id, event_id)
          if existing
            @attendances_repo.delete(existing.id)
          end
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
