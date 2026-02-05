# frozen_string_literal: true

module Tyto
  # Policy to determine if an account can view, edit, or delete events
  class EventPolicy
    def initialize(requestor, enrollment)
      @requestor = requestor
      @enrollment = enrollment
    end

    # Teaching staff (owner, instructor, staff) can create events
    def can_create?
      teaching_staff?
    end

    # Teaching staff can view events
    def can_view?
      teaching_staff?
    end

    # Teaching staff can update events
    def can_update?
      teaching_staff?
    end

    # Teaching staff can delete events
    def can_delete?
      teaching_staff?
    end

    # Summary of permissions
    def summary
      {
        can_view: can_view?,
        can_create: can_create?,
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
