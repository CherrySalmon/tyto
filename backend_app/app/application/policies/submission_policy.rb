# frozen_string_literal: true

module Tyto
  # Policy to determine if an account can manage submissions within a course.
  # Students can create/view their own submissions.
  # Teaching staff can view all submissions.
  class SubmissionPolicy
    def initialize(requestor, enrollment = nil)
      @requestor = requestor
      @enrollment = enrollment
    end

    # Students can submit (create/overwrite their own)
    def can_submit?
      student?
    end

    # Students can view their own; teaching staff can view all
    def can_view_own?
      enrolled?
    end

    # Teaching staff can view all submissions for an assignment
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

    def enrolled?
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
