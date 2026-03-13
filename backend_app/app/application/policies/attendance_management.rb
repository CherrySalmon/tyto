# frozen_string_literal: true

module Tyto
  module Policy
    # Determines if an actor can view or manage attendance records
    # for a course's events.
    class AttendanceManagement
      def initialize(requestor, course)
        @requestor = requestor
        @enrollment = course&.find_enrollment(requestor.account_id)
      end

      def can_view_all?
        teaching_staff?
      end

      def can_manage?
        requestor_is_instructor? || requestor_is_staff?
      end

      def summary
        {
          can_view_all: can_view_all?,
          can_manage: can_manage?
        }
      end

      private

      def teaching_staff?
        @enrollment&.teaching? || false
      end

      def requestor_is_instructor?
        @enrollment&.instructor? || false
      end

      def requestor_is_staff?
        @enrollment&.staff? || false
      end
    end
  end
end
