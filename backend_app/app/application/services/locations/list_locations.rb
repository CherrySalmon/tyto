# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../application_operation'

module Todo
  module Service
    module Locations
      # Service: List all locations for a course
      # Returns Success(ApiResult) with list of locations or Failure(ApiResult) with error
      class ListLocations < ApplicationOperation
        def initialize(locations_repo: Repository::Locations.new)
          @locations_repo = locations_repo
          super()
        end

        def call(requestor:, course_id:)
          course_id = step validate_course_id(course_id)
          step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          locations = step fetch_locations(course_id)

          ok(locations)
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

          return Failure(forbidden('You have no access to view locations')) unless policy.can_view?

          Success(true)
        end

        def fetch_locations(course_id)
          locations = @locations_repo.find_by_course(course_id)
          Success(locations)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
