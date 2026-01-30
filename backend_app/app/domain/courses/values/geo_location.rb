# frozen_string_literal: true

require_relative '../../types'

module Todo
  module Value
    # GeoLocation value object representing longitude/latitude coordinates.
    # Immutable and validated via type constraints.
    class GeoLocation < Dry::Struct
      EARTH_RADIUS_KM = 6371.0

      attribute :longitude, Types::Float.constrained(gteq: -180.0, lteq: 180.0)
      attribute :latitude, Types::Float.constrained(gteq: -90.0, lteq: 90.0)

      # Haversine formula for distance in kilometers
      # @param other [GeoLocation, NullGeoLocation] the other location
      # @return [Float] distance in kilometers (Float::INFINITY if other has no coordinates)
      def distance_to(other)
        return Float::INFINITY unless other.present?
        return 0.0 if self == other

        EARTH_RADIUS_KM * haversine_central_angle(other)
      end

      # Interface parity with Null Object
      def null? = false
      def present? = true

      private

      def haversine_central_angle(other)
        delta_lat = to_radians(other.latitude - latitude)
        delta_lon = to_radians(other.longitude - longitude)

        a = haversine_a(delta_lat, delta_lon, other)
        2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      end

      def haversine_a(delta_lat, delta_lon, other)
        Math.sin(delta_lat / 2)**2 +
          Math.cos(to_radians(latitude)) *
          Math.cos(to_radians(other.latitude)) *
          Math.sin(delta_lon / 2)**2
      end

      def to_radians(degrees)
        degrees * Math::PI / 180
      end
    end
  end
end
