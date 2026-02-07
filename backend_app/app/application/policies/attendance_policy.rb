# frozen_string_literal: true

module Tyto
  # Policy to determine if an account can view, edit, or record attendance
  class AttendancePolicy
    def initialize(requestor, enrollment)
      @requestor = requestor
      @enrollment = enrollment
    end

    # Enrolled users can create attendance (record their own attendance)
    def can_create?
      self_enrolled?
    end

    # Enrolled users can view their own attendance
    def can_view?
      self_enrolled?
    end

    # Teaching staff can view all attendance records
    def can_view_all?
      teaching_staff?
    end

    # Enrolled users can mark their own attendance
    def can_attend?
      self_enrolled?
    end

    # Summary of permissions
    def summary
      {
        can_view_all: can_view_all?,
        can_view: can_view?,
        can_create: can_create?,
        can_attend: can_attend?
      }
    end

    private

    # Check if the requestor is enrolled in the course
    def self_enrolled?
      @enrollment&.active? || false
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
