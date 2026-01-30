# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/events'
require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../application_operation'

module Tyto
  module Service
    module Events
      # Service: Find events active at a given time for the user's enrolled courses
      # Returns Success(ApiResult) with list of active events
      class FindActiveEvents < ApplicationOperation
        def initialize(events_repo: Repository::Events.new, locations_repo: Repository::Locations.new)
          @events_repo = events_repo
          @locations_repo = locations_repo
          super()
        end

        def call(requestor:, time: Time.now)
          time = step validate_time(time)
          course_ids = step get_user_course_ids(requestor)
          events = step find_active_events(course_ids, time)
          enriched = enrich_events_with_locations(events)

          ok(enriched)
        end

        private

        def validate_time(time)
          return Failure(bad_request('Invalid time')) if time.nil?

          parsed = time.is_a?(Time) ? time : Time.parse(time.to_s)
          Success(parsed)
        rescue ArgumentError
          Failure(bad_request('Invalid time format'))
        end

        def get_user_course_ids(requestor)
          account_id = requestor['account_id']
          return Failure(bad_request('Invalid requestor')) if account_id.nil?

          course_ids = AccountCourse.where(account_id:).select_map(:course_id)
          Success(course_ids)
        end

        def find_active_events(course_ids, time)
          # Return empty array if user isn't enrolled in any courses
          return Success([]) if course_ids.empty?

          events = @events_repo.find_active_at(course_ids, time)
          Success(events)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def enrich_events_with_locations(events)
          events.map do |event|
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
end
