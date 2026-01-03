# frozen_string_literal: true

# models/event.rb

require 'sequel'

module Todo
  class Event < Sequel::Model # rubocop:disable Style/Documentation
    plugin :validation_helpers

    many_to_one :course
    many_to_one :location
    one_to_many :attendances

    plugin :timestamps, update_on_create: true

    def validate
      super
      validates_presence %i[name location_id]
    end

    def self.list_event(course_id)
      events = Event.where(course_id: course_id).order(:start_at).all
      events.map(&:attributes)
    end

    def self.add_event(course_id, event_details)
      event = Event.find_or_create(
        course_id: course_id,
        name: event_details['name'],
        location_id: event_details['location_id'],
        start_at: event_details['start_at'],
        end_at: event_details['end_at'],
      )

      # Return the created event record details
    rescue StandardError => e
      # Handle error (e.g., validation errors)
      { error: "Failed to add event: #{e.message}" }
    end

    def self.find_event(requestor, time)
      course_ids = AccountCourse.where(account_id: requestor['account_id']).select_map(:course_id)
      events = Event.where{start_at <= time}.where{end_at >= time}.where(course_id: course_ids).all
      events.map(&:attributes)
    end

    def attributes
      {
        id:,
        course_id:,
        location_id:,
        name:,
        start_at:,
        end_at:,
        longitude: location.longitude,
        latitude: location.latitude,
      }
    end
  end
end
