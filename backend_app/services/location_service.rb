# frozen_string_literal: true

require_relative '../policies/location_policy'

module Todo
  # Manages Location requests
  class LocationService
    # Custom error classes
    class ForbiddenError < StandardError; end
    class LocationNotFoundError < StandardError; end

    # Lists all locations, if authorized
    def self.list_all(requestor, course_id)
      verify_policy(requestor, :view, course_id)
      locations = Location.where(course_id: course_id).all.map(&:attributes)

      locations || raise(ForbiddenError, 'You have no access to list locations.')
    end

    # Lists one locations based on the id, if authorized
    def self.get(requestor,location_id)
      verify_policy(requestor, :view)
      location = Location.first(id: location_id)
      location.attributes || raise(ForbiddenError, 'You have no access to list locations.')
    end


    # Creates a new location, if authorized
    def self.create(requestor, location_data, course_id)
      verify_policy(requestor, :create, course_id)
      location_data['course_id'] = course_id
      location = Location.create(location_data) || raise("Failed to create location.")
      location
    end

    # Updates an existing location, if authorized
    def self.update(requestor, course_id, location_id, location_data)
      location = Location.first(id: location_id) || raise(LocationNotFoundError, "Location with ID #{location_id} not found.")
      verify_policy(requestor, :update, course_id)
      location.update(location_data) || raise("Failed to update location with ID #{location_id}.")
    end

    # Removes an location, if authorized
    def self.remove(requestor, target_id, course_id)
      verify_policy(requestor, :delete, course_id)
      location = Location.first(id: target_id) || raise(LocationNotFoundError, "Laction with ID #{target_id} not found.")
      # Check if the location is associated with any events
      if location.events.any?
        raise("Location with ID #{target_id} cannot be deleted because it is associated with one or more events.")
      else
        location.destroy
      end
    end

    private

    # Checks authorization for the requested action
    def self.verify_policy(requestor, action = nil, course_id = nil)
      course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id: course_id).map do |role|
        role.role.name
      end
      policy = LocationPolicy.new(requestor, course_roles)
      action_check = action ? policy.send("can_#{action}?") : true
      raise(ForbiddenError, 'You have no access to perform this action.') unless action_check

      requestor
    end
  end
end
