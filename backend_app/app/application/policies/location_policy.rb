# frozen_string_literal: true

module Tyto
  # Policy to determine if an account can view, edit, or delete locations
  class LocationPolicy
    def initialize(requestor, enrollment)
      @requestor = requestor
      @enrollment = enrollment
    end

    # Only the course's teachers and staff can create a location
    def can_create?
      teaching_staff?
    end

    # Only enrolled users can view locations
    def can_view?
      @enrollment&.active? || false
    end

    # Only the course's teachers and staff can update a location
    def can_update?
      teaching_staff?
    end

    # Only the course's teachers and staff can delete a location
    def can_delete?
      teaching_staff?
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

    def requestor_is_admin?
      @requestor.admin?
    end

    def requestor_is_owner?
      @enrollment&.owner? || false
    end

    def requestor_is_instructor?
      @enrollment&.instructor? || false
    end

    def requestor_is_staff?
      @enrollment&.staff? || false
    end

    def teaching_staff?
      @enrollment&.teaching? || false
    end
  end
end
