# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/events'
require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../domain/shared/values/time_range'
require_relative '../../responses/event_details'
require_relative '../application_operation'

module Tyto
  module Service
    module Events
      # Service: Create a new event for a course
      # Returns Success(ApiResult) with created event or Failure(ApiResult) with error
      class CreateEvent < ApplicationOperation
        def initialize(events_repo: Repository::Events.new, locations_repo: Repository::Locations.new,
                       courses_repo: Repository::Courses.new)
          @events_repo = events_repo
          @locations_repo = locations_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, event_data:)
          course_id = step validate_course_id(course_id)
          course = step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          validated = step validate_input(event_data, course_id)
          event = step persist_event(validated)
          enriched = enrich_with_location(event, course)

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
          enrollment = @courses_repo.find_enrollment(account_id: requestor.account_id, course_id:)
          policy = Policy::Event.new(requestor, enrollment)

          return Failure(forbidden('You have no access to create events')) unless policy.can_create?

          Success(true)
        end

        def validate_input(event_data, course_id)
          name = validate_name(event_data['name'])
          return name if name.failure?

          location_id = validate_location_id(event_data['location_id'])
          return location_id if location_id.failure?

          time_range = Value::TimeRange.parse(event_data['start_at'], event_data['end_at'])

          Success(
            course_id:,
            location_id: location_id.value!,
            name: name.value!,
            start_at: time_range.start_at,
            end_at: time_range.end_at
          )
        rescue ArgumentError => e
          Failure(bad_request(e.message))
        end

        def validate_name(name)
          return Failure(bad_request('Event name is required')) if name.nil? || name.to_s.strip.empty?

          Success(name.strip)
        end

        def validate_location_id(location_id)
          return Failure(bad_request('Location ID is required')) if location_id.nil?

          Success(location_id.to_i)
        end

        def persist_event(validated)
          Success(@events_repo.create(build_event_entity(validated)))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def build_event_entity(row)
          Domain::Courses::Entities::Event.new(
            id: nil, created_at: nil, updated_at: nil,
            course_id: row[:course_id], location_id: row[:location_id],
            name: row[:name], start_at: row[:start_at], end_at: row[:end_at]
          )
        end

        def enrich_with_location(event, course)
          location = @locations_repo.find_id(event.location_id)
          Response::EventDetails.new(
            id: event.id, course_id: event.course_id, location_id: event.location_id,
            name: event.name, start_at: event.start_at, end_at: event.end_at,
            longitude: location&.longitude, latitude: location&.latitude,
            course_name: course.name, location_name: location&.name
          )
        end
      end
    end
  end
end
