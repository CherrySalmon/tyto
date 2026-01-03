# frozen_string_literal: true

module Todo
  # Policy to determine if an account can view, edit, or delete a particular course
  class AttendancePolicy
    def initialize(requestor, course = nil, course_roles = nil)
      @requestor = requestor
      @this_course = course
      @course_roles = course_roles
    end

    # Student can create a attendance;
    def can_create?
      self_enrolled?
    end

    # Student can view the attendance;
    def can_view?
      self_enrolled?
    end

    # Teaching staff can view all the attendance;
    def can_view_all?
      requestor_is_instructor? || requestor_is_owner? || requestor_is_staff?
    end

    # Student can update the attendance;
    def can_update?
      self_enrolled?
    end

    # Summary of permissions
    def summary
      {
        can_view_all: can_view_all?,
        can_view: can_view?,
        can_create: can_create?,
        can_update: can_update?
      }
    end

    private

    # Check if the requestor is enrolled in the course
    def self_enrolled?
      @this_course&.accounts&.any? { |account| account.id == @requestor['account_id'] }
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
