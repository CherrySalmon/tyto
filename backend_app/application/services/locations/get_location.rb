# frozen_string_literal: true

require_relative '../../policies/location_policy'
require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../application_operation'

module Todo
  module Service
    module Locations
      # Service: Get a single location by ID
      # Returns Success(ApiResult) with location or Failure(ApiResult) with error
      class GetLocation < ApplicationOperation
        def initialize(locations_repo: Repository::Locations.new)
          @locations_repo = locations_repo
          super()
        end

        def call(requestor:, location_id:)
          location_id = step validate_location_id(location_id)
          location = step find_location(location_id)
          step authorize(requestor, location.course_id)

          ok(location)
        end

        private

        def validate_location_id(location_id)
          id = location_id.to_i
          return Failure(bad_request('Invalid location ID')) if id.zero?

          Success(id)
        end

        def find_location(location_id)
          location = @locations_repo.find_id(location_id)
          return Failure(not_found("Location with ID #{location_id} not found")) unless location

          Success(location)
        end

        def authorize(requestor, course_id)
          course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id:).map do |ac|
            ac.role.name
          end
          policy = LocationPolicy.new(requestor, course_roles)

          return Failure(forbidden('You have no access to view this location')) unless policy.can_view?

          Success(true)
        end
      end
    end
  end
end
