# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/locations'
require_relative '../application_operation'

module Tyto
  module Service
    module Locations
      # Service: Delete an existing location
      # Returns Success(ApiResult) or Failure(ApiResult) with error
      class DeleteLocation < ApplicationOperation
        def initialize(locations_repo: Repository::Locations.new)
          @locations_repo = locations_repo
          super()
        end

        def call(requestor:, course_id:, location_id:)
          course_id = step validate_course_id(course_id)
          location_id = step validate_location_id(location_id)
          step verify_course_exists(course_id)
          step find_location(location_id, course_id)
          step authorize(requestor, course_id)
          step check_no_associated_events(location_id)
          step delete_location(location_id)

          ok('Location deleted')
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

          return Failure(forbidden('You have no access to delete locations')) unless policy.can_delete?

          Success(true)
        end

        def check_no_associated_events(location_id)
          if @locations_repo.has_events?(location_id)
            return Failure(bad_request('Cannot delete location with associated events'))
          end

          Success(true)
        end

        def delete_location(location_id)
          deleted = @locations_repo.delete(location_id)
          return Failure(internal_error('Failed to delete location')) unless deleted

          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
