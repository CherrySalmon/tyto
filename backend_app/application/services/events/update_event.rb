# frozen_string_literal: true

require_relative '../../policies/event_policy'
require_relative '../../../infrastructure/database/repositories/events'
require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../application_operation'

module Todo
  module Service
    module Events
      # Service: Update an existing event
      # Returns Success(ApiResult) with updated event or Failure(ApiResult) with error
      class UpdateEvent < ApplicationOperation
        def initialize(events_repo: Repository::Events.new, locations_repo: Repository::Locations.new)
          @events_repo = events_repo
          @locations_repo = locations_repo
          super()
        end

        def call(requestor:, course_id:, event_id:, event_data:)
          course_id = step validate_course_id(course_id)
          event_id = step validate_event_id(event_id)
          step verify_course_exists(course_id)
          existing = step find_event(event_id, course_id)
          step authorize(requestor, course_id)
          validated = step validate_input(event_data, existing)
          updated = step persist_update(existing, validated)
          enriched = enrich_with_location(updated)

          ok(enriched)
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

        def find_event(event_id, course_id)
          event = @events_repo.find_id(event_id)
          return Failure(not_found("Event with ID #{event_id} not found")) unless event
          return Failure(bad_request('Event does not belong to this course')) unless event.course_id == course_id

          Success(event)
        end

        def authorize(requestor, course_id)
          course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id:).map do |ac|
            ac.role.name
          end
          policy = EventPolicy.new(requestor, course_roles)

          return Failure(forbidden('You have no access to update events')) unless policy.can_update?

          Success(true)
        end

        def validate_input(event_data, existing)
          # For updates, all fields are optional - use existing values as fallback
          name = validate_name(event_data['name'], existing.name)
          return name if name.failure?

          location_id = validate_location_id(event_data['location_id'], existing.location_id)
          return location_id if location_id.failure?

          times = validate_times(event_data['start_at'], event_data['end_at'], existing)
          return times if times.failure?

          Success(
            location_id: location_id.value!,
            name: name.value!,
            start_at: times.value![:start_at],
            end_at: times.value![:end_at]
          )
        end

        def validate_name(name, existing_name)
          # Use existing name if not provided
          return Success(existing_name) if name.nil?

          # If provided, must be non-empty
          return Failure(bad_request('Event name cannot be empty')) if name.to_s.strip.empty?

          Success(name.strip)
        end

        def validate_location_id(location_id, existing_location_id)
          # Use existing location if not provided
          return Success(existing_location_id) if location_id.nil?

          Success(location_id.to_i)
        end

        def validate_times(start_at, end_at, existing)
          # Use existing times as fallback
          start_time = start_at ? parse_time(start_at) : existing.start_at
          end_time = end_at ? parse_time(end_at) : existing.end_at

          # Only validate if explicit values were provided and are invalid
          return Failure(bad_request('Invalid start time format')) if start_at && start_time.nil?
          return Failure(bad_request('Invalid end time format')) if end_at && end_time.nil?

          # Cross-field validation: end must be after start (using final computed values)
          if start_time && end_time && end_time <= start_time
            return Failure(bad_request('End time must be after start time'))
          end

          Success(start_at: start_time, end_at: end_time)
        end

        def persist_update(existing, validated)
          updated_entity = existing.new(
            location_id: validated[:location_id],
            name: validated[:name],
            start_at: validated[:start_at],
            end_at: validated[:end_at]
          )

          Success(@events_repo.update(updated_entity))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def enrich_with_location(event)
          location = @locations_repo.find_id(event.location_id)

          OpenStruct.new(
            id: event.id,
            course_id: event.course_id,
            location_id: event.location_id,
            name: event.name,
            start_at: event.start_at,
            end_at: event.end_at,
            longitude: location&.longitude,
            latitude: location&.latitude
          )
        end

        def parse_time(time_value)
          return nil unless time_value

          time_value.is_a?(Time) ? time_value.utc : Time.parse(time_value.to_s).utc
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
