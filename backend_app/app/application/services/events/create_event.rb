# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/events'
require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../application_operation'

module Todo
  module Service
    module Events
      # Service: Create a new event for a course
      # Returns Success(ApiResult) with created event or Failure(ApiResult) with error
      class CreateEvent < ApplicationOperation
        def initialize(events_repo: Repository::Events.new, locations_repo: Repository::Locations.new)
          @events_repo = events_repo
          @locations_repo = locations_repo
          super()
        end

        def call(requestor:, course_id:, event_data:)
          course_id = step validate_course_id(course_id)
          step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          validated = step validate_input(event_data, course_id)
          event = step persist_event(validated)
          enriched = enrich_with_location(event)

          created(enriched)
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
          course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id:).map do |ac|
            ac.role.name
          end
          policy = EventPolicy.new(requestor, course_roles)

          return Failure(forbidden('You have no access to create events')) unless policy.can_create?

          Success(true)
        end

        def validate_input(event_data, course_id)
          name = validate_name(event_data['name'])
          return name if name.failure?

          location_id = validate_location_id(event_data['location_id'])
          return location_id if location_id.failure?

          times = validate_times(event_data['start_at'], event_data['end_at'])
          return times if times.failure?

          Success(
            course_id:,
            location_id: location_id.value!,
            name: name.value!,
            start_at: times.value![:start_at],
            end_at: times.value![:end_at]
          )
        end

        def validate_name(name)
          return Failure(bad_request('Event name is required')) if name.nil? || name.to_s.strip.empty?

          Success(name.strip)
        end

        def validate_location_id(location_id)
          return Failure(bad_request('Location ID is required')) if location_id.nil?

          Success(location_id.to_i)
        end

        def validate_times(start_at, end_at)
          start_time = parse_time(start_at)
          end_time = parse_time(end_at)

          return Failure(bad_request('Start time is required')) if start_time.nil?
          return Failure(bad_request('End time is required')) if end_time.nil?
          return Failure(bad_request('End time must be after start time')) if end_time <= start_time

          Success(start_at: start_time, end_at: end_time)
        end

        def persist_event(validated)
          entity = Entity::Event.new(
            id: nil,
            course_id: validated[:course_id],
            location_id: validated[:location_id],
            name: validated[:name],
            start_at: validated[:start_at],
            end_at: validated[:end_at],
            created_at: nil,
            updated_at: nil
          )

          Success(@events_repo.create(entity))
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
