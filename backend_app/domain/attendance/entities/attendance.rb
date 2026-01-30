# frozen_string_literal: true

require_relative '../../types'
require_relative '../../courses/values/geo_location'
require_relative '../../courses/values/null_geo_location'

module Todo
  module Entity
    # Attendance entity - represents a check-in record for an event.
    # Pure domain object with no infrastructure dependencies.
    # Immutable - updates create new instances via `new()`.
    class Attendance < Dry::Struct
      attribute :id, Types::Integer.optional
      attribute :account_id, Types::Integer
      attribute :course_id, Types::Integer
      attribute :event_id, Types::Integer.optional
      attribute :role_id, Types::Integer.optional
      attribute :name, Types::String.optional
      attribute :longitude, Types::Float.optional
      attribute :latitude, Types::Float.optional
      attribute :created_at, Types::Time.optional
      attribute :updated_at, Types::Time.optional

      # Returns a GeoLocation value object for check-in coordinates,
      # or NullGeoLocation if coordinates are missing.
      def check_in_location
        return Value::NullGeoLocation.new unless longitude && latitude

        Value::GeoLocation.new(longitude:, latitude:)
      end

      # Check if this attendance has check-in coordinates
      def has_coordinates? = check_in_location.present?

      # Calculate distance from check-in location to event location
      # @param event_location [Entity::Location] the event's location
      # @return [Float] distance in kilometers (Float::INFINITY if coordinates missing)
      def distance_to_event(event_location)
        check_in_location.distance_to(event_location.geo_location)
      end

      # Check if check-in was within acceptable distance of event location
      # @param event_location [Entity::Location] the event's location
      # @param max_distance_km [Float] maximum allowed distance in km
      # @return [Boolean] true if within range (false if coordinates missing)
      def within_range?(event_location, max_distance_km: 0.5)
        distance = distance_to_event(event_location)
        distance <= max_distance_km
      end
    end
  end
end
