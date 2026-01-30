# frozen_string_literal: true

module Tyto
  # Policy to determine if an requestor can view, edit, or delete a particular course
  class LocationPolicy
    def initialize(requestor, course_roles)
      @requestor = requestor
      @course_roles = course_roles
    end

    # Only the course's teachers and staff can update a location
    def can_create? #expect student
      requestor_is_owner? || requestor_is_instructor? || requestor_is_staff?
    end

    # Only enrolled users can view locations
    def can_view?
      @course_roles.any?
    end

    # Only the course's teachers and staff can update a location
    def can_update? #expect student
      requestor_is_owner? || requestor_is_instructor? || requestor_is_staff?
    end

    # Only the course's teachers and staff can update a location
    def can_delete? #expect student
      requestor_is_owner? || requestor_is_instructor? || requestor_is_staff?
    end

    def summary
      {
        can_create: can_create?,
        can_view: can_view?,
        can_update: can_update?,
        can_delete: can_delete?
      }
    end

    private

    # Check if the requestor has an admin role
    def requestor_is_admin?
      @requestor['roles'].include?('admin')
    end

    def requestor_is_instructor?
      @course_roles.include?('instructor')
    end

    def requestor_is_staff?
      @course_roles.include?('staff')
    end

    def requestor_is_owner?
      @course_roles.include?('owner')
    end
  end
end
