# frozen_string_literal: true

require_relative '../../types'
require_relative '../values/geo_location'
require_relative '../values/null_geo_location'

module Tyto
  module Entity
    # Location entity within the Courses bounded context.
    # Locations belong to a Course and can be assigned to Events.
    # Pure domain object with no infrastructure dependencies.
    # Immutable - updates create new instances via `new()`.
    class Location < Dry::Struct
      attribute :id, Types::Integer.optional
      attribute :course_id, Types::Integer
      attribute :name, Types::LocationName
      attribute :longitude, Types::Float.optional
      attribute :latitude, Types::Float.optional
      attribute :created_at, Types::Time.optional
      attribute :updated_at, Types::Time.optional

      # Returns a GeoLocation value object, or NullGeoLocation if coordinates are missing.
      # Uses Null Object pattern to eliminate nil checks in delegating methods.
      def geo_location
        return Value::NullGeoLocation.new unless longitude && latitude

        Value::GeoLocation.new(longitude:, latitude:)
      end

      # Delegates to geo_location (no guards needed - Null Object handles it)
      def distance_to(other_location)
        geo_location.distance_to(other_location.geo_location)
      end

      # Check if this location has coordinates
      def has_coordinates? = geo_location.present?
    end
  end
end
