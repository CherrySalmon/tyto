# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/events'
require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../responses/event_details'
require_relative '../application_operation'

module Tyto
  module Service
    module Events
      # Service: List all events for a course
      # Returns Success(ApiResult) with event entities or Failure(ApiResult) with error
      class ListEvents < ApplicationOperation
        def initialize(events_repo: Repository::Events.new, locations_repo: Repository::Locations.new,
                       courses_repo: Repository::Courses.new)
          @events_repo = events_repo
          @locations_repo = locations_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:)
          course_id = step validate_course_id(course_id)
          course = step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          events = step fetch_events(course_id)
          enriched = enrich_events(events, course)

          ok(enriched)
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
          policy = EventPolicy.new(requestor, enrollment)

          return Failure(forbidden('You have no access to view events')) unless policy.can_view?

          Success(true)
        end

        def fetch_events(course_id)
          Success(@events_repo.find_by_course(course_id))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def enrich_events(events, course)
          return [] if events.empty?

          location_ids = events.map(&:location_id).compact.uniq
          locations = @locations_repo.find_ids(location_ids)

          events.map do |event|
            location = locations[event.location_id]

            Response::EventDetails.new(
              id: event.id,
              course_id: event.course_id,
              location_id: event.location_id,
              name: event.name,
              start_at: event.start_at,
              end_at: event.end_at,
              longitude: location&.longitude,
              latitude: location&.latitude,
              course_name: course.name,
              location_name: location&.name
            )
          end
        end
      end
    end
  end
end
