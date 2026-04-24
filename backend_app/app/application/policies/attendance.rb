# frozen_string_literal: true

module Tyto
  module Policy
    # Determines if an enrolled actor can perform self-service attendance
    # operations (view or record their own attendance).
    class Attendance
      def initialize(requestor, enrollment)
        @requestor = requestor
        @enrollment = enrollment
      end

      def can_view?
        self_enrolled?
      end

      def can_attend?
        self_enrolled?
      end

      def summary
        {
          can_view: can_view?,
          can_attend: can_attend?
        }
      end

      private

      def self_enrolled?
        @enrollment&.active? || false
      end
    end
  end
end
