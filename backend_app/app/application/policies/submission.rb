# frozen_string_literal: true

module Tyto
  module Policy
    # Authorization for submission operations.
    # Students can create and view their own submissions.
    # Teaching staff can view all submissions for an assignment.
    class Submission
      def initialize(requestor, enrollment = nil)
        @requestor = requestor
        @enrollment = enrollment
      end

      def can_submit?
        student?
      end

      def can_view_own?
        self_enrolled?
      end

      def can_view_all?
        teaching_staff?
      end

      def summary
        {
          can_submit: can_submit?,
          can_view_own: can_view_own?,
          can_view_all: can_view_all?
        }
      end

      private

      def self_enrolled?
        @enrollment&.active? || false
      end

      def student?
        @enrollment&.student? || false
      end

      def teaching_staff?
        @enrollment&.teaching? || false
      end
    end
  end
end
