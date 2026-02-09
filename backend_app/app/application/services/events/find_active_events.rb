# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/events'
require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../infrastructure/database/repositories/attendances'
require_relative '../../responses/active_event_details'
require_relative '../application_operation'

module Tyto
  module Service
    module Events
      # Service: Find events active at a given time for the user's enrolled courses
      # Returns Success(ApiResult) with list of active events
      class FindActiveEvents < ApplicationOperation
        def initialize(events_repo: Repository::Events.new, locations_repo: Repository::Locations.new,
                       courses_repo: Repository::Courses.new, attendances_repo: Repository::Attendances.new)
          @events_repo = events_repo
          @locations_repo = locations_repo
          @courses_repo = courses_repo
          @attendances_repo = attendances_repo
          super()
        end

        def call(requestor:, time: Time.now)
          time = step validate_time(time)
          course_ids = step get_user_course_ids(requestor)
          events = step find_active_events(course_ids, time)
          enriched = enrich_events(events, requestor)

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
          return Failure(bad_request('Invalid requestor')) unless requestor.respond_to?(:account_id)

          account_id = requestor.account_id
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

        def enrich_events(events, requestor)
          return [] if events.empty?

          location_ids = events.map(&:location_id).compact.uniq
          course_ids = events.map(&:course_id).compact.uniq
          event_ids = events.map(&:id)

          locations = @locations_repo.find_ids(location_ids)
          courses = @courses_repo.find_ids(course_ids)
          attended = @attendances_repo.find_attended_event_ids(requestor.account_id, event_ids)

          events.map do |event|
            location = locations[event.location_id]
            course = courses[event.course_id]

            Response::ActiveEventDetails.new(
              id: event.id,
              course_id: event.course_id,
              location_id: event.location_id,
              name: event.name,
              start_at: event.start_at,
              end_at: event.end_at,
              longitude: location&.longitude,
              latitude: location&.latitude,
              course_name: course&.name,
              location_name: location&.name,
              user_attendance_status: attended.include?(event.id)
            )
          end
        end
      end
    end
  end
end
