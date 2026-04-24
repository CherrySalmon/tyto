# frozen_string_literal: true

module Tyto
  module Policy
    # Authorization for assignment operations.
    # Teaching staff (owner, instructor, staff) have full CRUD + publish.
    # Students can only view published assignments and submit to them.
    class Assignment
      def initialize(requestor, enrollment = nil, has_submissions: false)
        @requestor = requestor
        @enrollment = enrollment
        @has_submissions = has_submissions
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

      # Teaching staff can delete only while no submissions exist.
      # Once a student has submitted, use the disabled lifecycle state instead.
      def can_delete?
        teaching_staff? && !@has_submissions
      end

      def can_publish?
        teaching_staff?
      end

      # Teaching staff can unpublish only while no submissions exist.
      # Otherwise hiding the assignment would orphan student work.
      def can_unpublish?
        teaching_staff? && !@has_submissions
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
