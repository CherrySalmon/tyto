# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/events'
require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../application_operation'

module Tyto
  module Service
    module Events
      # Service: List all events for a course
      # Returns Success(ApiResult) with event entities or Failure(ApiResult) with error
      class ListEvents < ApplicationOperation
        def initialize(events_repo: Repository::Events.new, locations_repo: Repository::Locations.new)
          @events_repo = events_repo
          @locations_repo = locations_repo
          super()
        end

        def call(requestor:, course_id:)
          course_id = step validate_course_id(course_id)
          step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          events = step fetch_events(course_id)
          enriched = events.map { |event| enrich_with_location(event) }

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
          course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id:).map do |ac|
            ac.role.name
          end
          policy = EventPolicy.new(requestor, course_roles)

          return Failure(forbidden('You have no access to view events')) unless policy.can_view?

          Success(true)
        end

        def fetch_events(course_id)
          Success(@events_repo.find_by_course(course_id))
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
      end
    end
  end
end
