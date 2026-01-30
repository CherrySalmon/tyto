# frozen_string_literal: true

module Tyto
  # Policy to determine if an account can view, edit, or delete courses
  class CoursePolicy
    def initialize(requestor, enrollment = nil)
      @requestor = requestor
      @enrollment = enrollment
    end

    # Only admins can view all courses
    def can_view_all?
      requestor_is_admin?
    end

    # Only creators can create courses
    def can_create?
      requestor_is_creator?
    end

    # Enrolled users can view the course
    def can_view?
      self_enrolled?
    end

    # Teaching staff can update the course
    def can_update?
      teaching_staff?
    end

    # Admins or course owners can delete the course
    def can_delete?
      requestor_is_admin? || requestor_is_owner?
    end

    def summary
      {
        can_view_all: can_view_all?,
        can_view: can_view?,
        can_create: can_create?,
        can_update: can_update?,
        can_delete: can_delete?
      }
    end

    private

    # Check if the requestor is enrolled in the course
    def self_enrolled?
      @enrollment&.active? || false
    end

    # Check if the requestor has an admin role (global role)
    def requestor_is_admin?
      @requestor.admin?
    end

    # Check if the requestor has a creator role (global role)
    def requestor_is_creator?
      @requestor.creator?
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
