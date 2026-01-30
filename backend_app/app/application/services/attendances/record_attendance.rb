# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/attendances'
require_relative '../../../infrastructure/database/repositories/events'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Attendances
      # Service: Record attendance (check-in) for an event
      # Returns Success(ApiResult) with created attendance or Failure(ApiResult) with error
      class RecordAttendance < ApplicationOperation
        def initialize(attendances_repo: Repository::Attendances.new, events_repo: Repository::Events.new,
                       courses_repo: Repository::Courses.new)
          @attendances_repo = attendances_repo
          @events_repo = events_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, attendance_data:)
          course_id = step validate_course_id(course_id)
          step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          validated = step validate_input(attendance_data, requestor, course_id)
          attendance = step persist_attendance(validated)

          created(attendance)
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

        def authorize(requestor, course_id)
          enrollment = @courses_repo.find_enrollment(account_id: requestor.account_id, course_id:)
          policy = AttendancePolicy.new(requestor, enrollment)

          return Failure(forbidden('You have no access to record attendance')) unless policy.can_create?

          Success(true)
        end

        def validate_input(attendance_data, requestor, course_id)
          event_id = validate_event_id(attendance_data['event_id'])
          return event_id if event_id.failure?

          event = @events_repo.find_id(event_id.value!)
          return Failure(not_found('Event not found')) unless event
          return Failure(bad_request('Event does not belong to this course')) unless event.course_id == course_id

          coordinates = validate_coordinates(attendance_data['longitude'], attendance_data['latitude'])
          return coordinates if coordinates.failure?

          # Get the student role ID
          student_role = Role.first(name: 'student')
          return Failure(internal_error('Student role not found')) unless student_role

          # Generate name from event if not provided
          name = attendance_data['name'] || "#{event.name} Attendance"

          Success(
            account_id: requestor.account_id,
            course_id: course_id,
            event_id: event_id.value!,
            role_id: student_role.id,
            name: name,
            longitude: coordinates.value![:longitude],
            latitude: coordinates.value![:latitude]
          )
        end

        def validate_event_id(event_id)
          return Failure(bad_request('Event ID is required')) if event_id.nil?

          id = event_id.to_i
          return Failure(bad_request('Invalid event ID')) if id.zero?

          Success(id)
        end

        def validate_coordinates(longitude, latitude)
          # Coordinates are optional for attendance
          return Success(longitude: nil, latitude: nil) if longitude.nil? && latitude.nil?

          # If one is provided, both must be provided
          if (longitude.nil? && !latitude.nil?) || (!longitude.nil? && latitude.nil?)
            return Failure(bad_request('Both longitude and latitude must be provided together'))
          end

          lng = longitude.to_f
          lat = latitude.to_f

          return Failure(bad_request('Longitude must be between -180 and 180')) unless lng.between?(-180, 180)
          return Failure(bad_request('Latitude must be between -90 and 90')) unless lat.between?(-90, 90)

          Success(longitude: lng, latitude: lat)
        end

        def persist_attendance(validated)
          entity = Entity::Attendance.new(
            id: nil,
            account_id: validated[:account_id],
            course_id: validated[:course_id],
            event_id: validated[:event_id],
            role_id: validated[:role_id],
            name: validated[:name],
            longitude: validated[:longitude],
            latitude: validated[:latitude],
            created_at: nil,
            updated_at: nil
          )

          Success(@attendances_repo.create(entity))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
