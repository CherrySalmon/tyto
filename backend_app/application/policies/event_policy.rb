# frozen_string_literal: true

module Todo
  # Policy to determine if an account can view, edit, or delete a particular course
  class EventPolicy
    def initialize(requestor, course_roles)
      @requestor = requestor
      @course_roles = course_roles
    end

    # Instructor and staff can view all events;
    # def can_view_all?
    #   requestor_is_instructor? || requestor_is_staff?
    # end

    # Instructor and staff can create a event;
    def can_create?
      requestor_is_owner? || requestor_is_instructor? || requestor_is_staff?
    end

    # Instructor and staff can view a event;
    def can_view?
      requestor_is_owner? || requestor_is_instructor? || requestor_is_staff?
    end

    # Student can update the attendance;
    def can_update?
      requestor_is_owner? || requestor_is_instructor? || requestor_is_staff?
    end

    def can_delete?
      requestor_is_owner? || requestor_is_instructor? || requestor_is_staff?
    end

    # Summary of permissions
    def summary
      {
        can_view: can_view?,
        can_create: can_create?,
        can_update: can_update?,
        can_delete: can_delete?,
      }
    end

    private

    # Check if the requestor is enrolled in the course
    def self_enrolled?
      @this_course&.accounts&.any? { |account| account.id == @requestor['account_id'] }
    end

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
