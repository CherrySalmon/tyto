# frozen_string_literal: true

module Tyto
  module Policy
    # Authorization for assignment operations.
    # Teaching staff (owner, instructor, staff) have full CRUD + publish.
    # Students can only view published assignments and submit to them.
    class Assignment
      def initialize(requestor, enrollment = nil)
        @requestor = requestor
        @enrollment = enrollment
      end

      def can_create?
        teaching_staff?
      end

      def can_view?
        self_enrolled?
      end

      def can_update?
        teaching_staff?
      end

      def can_delete?
        teaching_staff?
      end

      def can_publish?
        teaching_staff?
      end

      def can_unpublish?
        teaching_staff?
      end

      def can_view_drafts?
        teaching_staff?
      end

      # Whether the user can submit to assignments (students only).
      # Included here so the assignment detail response has everything
      # the frontend needs without a separate submission policy call.
      def can_submit?
        student?
      end

      def summary
        {
          can_create: can_create?,
          can_view: can_view?,
          can_update: can_update?,
          can_delete: can_delete?,
          can_publish: can_publish?,
          can_unpublish: can_unpublish?,
          can_view_drafts: can_view_drafts?,
          can_submit: can_submit?
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
