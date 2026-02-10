# frozen_string_literal: true

module Tyto
  module Value
    # Null object for GeoLocation when coordinates are not available.
    # Provides safe defaults that eliminate nil checks in calling code.
    class NullGeoLocation
      def longitude = nil
      def latitude = nil

      # Distance to anywhere is undefined when location is unknown
      def distance_to(_other) = Float::INFINITY

      # Null object interface
      def null? = true
      def present? = false

      # Equality: all null geo locations are equal
      def ==(other)
        other.is_a?(NullGeoLocation)
      end
      alias eql? ==

      def hash
        self.class.hash
      end
    end
  end
end
