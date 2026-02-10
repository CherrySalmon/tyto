# frozen_string_literal: true

require_relative '../../../domain/shared/values/geo_location'

module Tyto
  module Service
    # Shared coordinate validation for services that handle geo-locations.
    # Delegates validation to GeoLocation value object (single source of truth).
    module CoordinateValidation
      # Validates longitude/latitude coordinates.
      # @param longitude [Numeric, nil] longitude value
      # @param latitude [Numeric, nil] latitude value
      # @return [Dry::Monads::Result] Success with coordinate hash or Failure with error
      def validate_coordinates(longitude, latitude)
        # Both nil is valid (no coordinates)
        return Success(longitude: nil, latitude: nil) if longitude.nil? && latitude.nil?

        # Must provide both or neither
        if longitude.nil? != latitude.nil?
          return Failure(bad_request('Both longitude and latitude must be provided together'))
        end

        # Delegate validation to domain value object
        geo = Value::GeoLocation.build(longitude:, latitude:)
        Success(longitude: geo.longitude, latitude: geo.latitude)
      rescue Value::GeoLocation::InvalidCoordinatesError => e
        Failure(bad_request(e.message))
      end
    end
  end
end
