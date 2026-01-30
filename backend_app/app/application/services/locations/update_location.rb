# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../application_operation'

module Tyto
  module Service
    module Locations
      # Service: Update an existing location
      # Returns Success(ApiResult) with updated location or Failure(ApiResult) with error
      class UpdateLocation < ApplicationOperation
        def initialize(locations_repo: Repository::Locations.new)
          @locations_repo = locations_repo
          super()
        end

        def call(requestor:, course_id:, location_id:, location_data:)
          course_id = step validate_course_id(course_id)
          location_id = step validate_location_id(location_id)
          step verify_course_exists(course_id)
          existing = step find_location(location_id, course_id)
          step authorize(requestor, course_id)
          validated = step validate_input(location_data, existing)
          updated = step persist_update(existing, validated)

          ok(updated)
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def validate_location_id(location_id)
          id = location_id.to_i
          return Failure(bad_request('Invalid location ID')) if id.zero?

          Success(id)
        end

        def verify_course_exists(course_id)
          course = Course.first(id: course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def find_location(location_id, course_id)
          location = @locations_repo.find_id(location_id)
          return Failure(not_found("Location with ID #{location_id} not found")) unless location
          return Failure(bad_request('Location does not belong to this course')) unless location.course_id == course_id

          Success(location)
        end

        def authorize(requestor, course_id)
          course_roles = AccountCourse.where(account_id: requestor.account_id, course_id:).map do |ac|
            ac.role.name
          end
          policy = LocationPolicy.new(requestor, course_roles)

          return Failure(forbidden('You have no access to update locations')) unless policy.can_update?

          Success(true)
        end

        def validate_input(location_data, existing)
          name = validate_name(location_data['name'], existing.name)
          return name if name.failure?

          coordinates = validate_coordinates(location_data, existing)
          return coordinates if coordinates.failure?

          Success(
            name: name.value!,
            longitude: coordinates.value![:longitude],
            latitude: coordinates.value![:latitude]
          )
        end

        def validate_name(name, existing_name)
          return Success(existing_name) if name.nil?
          return Failure(bad_request('Location name cannot be empty')) if name.to_s.strip.empty?

          Success(name.strip)
        end

        def validate_coordinates(location_data, existing)
          # Use existing values as defaults
          longitude = location_data.key?('longitude') ? location_data['longitude'] : existing.longitude
          latitude = location_data.key?('latitude') ? location_data['latitude'] : existing.latitude

          # Allow clearing coordinates (both nil)
          return Success(longitude: nil, latitude: nil) if longitude.nil? && latitude.nil?

          # If one is provided, both must be provided
          if (longitude.nil? && !latitude.nil?) || (!longitude.nil? && latitude.nil?)
            return Failure(bad_request('Both longitude and latitude must be provided together'))
          end

          lng = longitude.to_f
          lat = latitude.to_f

          return Failure(bad_request('Longitude must be between -180 and 180')) unless lng.between?(-180, 180)
          return Failure(bad_request('Latitude must be between -90 and 90')) unless lat.between?(-90, 90)

          Success(longitude: lng, latitude: lat)
        end

        def persist_update(existing, validated)
          updated_entity = existing.new(
            name: validated[:name],
            longitude: validated[:longitude],
            latitude: validated[:latitude]
          )

          Success(@locations_repo.update(updated_entity))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
