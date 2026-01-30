# frozen_string_literal: true

require_relative '../../policies/location_policy'
require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../application_operation'

module Todo
  module Service
    module Locations
      # Service: Create a new location for a course
      # Returns Success(ApiResult) with created location or Failure(ApiResult) with error
      class CreateLocation < ApplicationOperation
        def initialize(locations_repo: Repository::Locations.new)
          @locations_repo = locations_repo
          super()
        end

        def call(requestor:, course_id:, location_data:)
          course_id = step validate_course_id(course_id)
          step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          validated = step validate_input(location_data, course_id)
          location = step persist_location(validated)

          created(location)
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
          policy = LocationPolicy.new(requestor, course_roles)

          return Failure(forbidden('You have no access to create locations')) unless policy.can_create?

          Success(true)
        end

        def validate_input(location_data, course_id)
          name = validate_name(location_data['name'])
          return name if name.failure?

          coordinates = validate_coordinates(location_data['longitude'], location_data['latitude'])
          return coordinates if coordinates.failure?

          Success(
            course_id:,
            name: name.value!,
            longitude: coordinates.value![:longitude],
            latitude: coordinates.value![:latitude]
          )
        end

        def validate_name(name)
          return Failure(bad_request('Location name is required')) if name.nil? || name.to_s.strip.empty?

          Success(name.strip)
        end

        def validate_coordinates(longitude, latitude)
          # Coordinates are optional
          return Success(longitude: nil, latitude: nil) if longitude.nil? && latitude.nil?

          # If one is provided, both must be provided
          if (longitude.nil? && !latitude.nil?) || (!longitude.nil? && latitude.nil?)
            return Failure(bad_request('Both longitude and latitude must be provided together'))
          end

          lng = longitude.to_f
          lat = latitude.to_f

          # Validate ranges
          return Failure(bad_request('Longitude must be between -180 and 180')) unless lng.between?(-180, 180)
          return Failure(bad_request('Latitude must be between -90 and 90')) unless lat.between?(-90, 90)

          Success(longitude: lng, latitude: lat)
        end

        def persist_location(validated)
          entity = Entity::Location.new(
            id: nil,
            course_id: validated[:course_id],
            name: validated[:name],
            longitude: validated[:longitude],
            latitude: validated[:latitude],
            created_at: nil,
            updated_at: nil
          )

          Success(@locations_repo.create(entity))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
