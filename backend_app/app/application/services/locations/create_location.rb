# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'
require_relative '../concerns/coordinate_validation'

module Tyto
  module Service
    module Locations
      # Service: Create a new location for a course
      # Returns Success(ApiResult) with created location or Failure(ApiResult) with error
      class CreateLocation < ApplicationOperation
        include CoordinateValidation
        def initialize(locations_repo: Repository::Locations.new, courses_repo: Repository::Courses.new)
          @locations_repo = locations_repo
          @courses_repo = courses_repo
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
          enrollment = @courses_repo.find_enrollment(account_id: requestor.account_id, course_id:)
          policy = LocationPolicy.new(requestor, enrollment)

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

        def persist_location(validated)
          entity = Domain::Courses::Entities::Location.new(
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
