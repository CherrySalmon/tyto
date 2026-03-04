# frozen_string_literal: true

require_relative '../../types'
require_relative '../values/submission_requirements'

module Tyto
  module Domain
    module Assignments
      module Entities
        # Assignment aggregate root entity.
        # Represents a task assigned to students within a course.
        # Has a draft/published/disabled lifecycle.
        # Pure domain object with no infrastructure dependencies.
        # Immutable - updates create new instances via `new()`.
        #
        # Child collection uses typed collection value object:
        #   nil  = not loaded (calling methods on nil raises NoMethodError)
        #   SubmissionRequirements = loaded
        # Callers must construct collection objects explicitly via .from().
        class Assignment < Dry::Struct
          attribute :id, Types::Integer.optional
          attribute :course_id, Types::Integer
          attribute :event_id, Types::Integer.optional.default(nil)
          attribute :title, Types::AssignmentTitle
          attribute :description, Types::String.optional.default(nil)
          # Inline default+enum: dry-types named types (e.g. AssignmentStatus) don't support .default()
          attribute :status, Types::String.default('draft'.freeze).enum('draft', 'published', 'disabled')
          attribute :due_at, Types::Time.optional.default(nil)
          attribute :allow_late_resubmit, Types::Bool.default(false)
          attribute :created_at, Types::Time.optional
          attribute :updated_at, Types::Time.optional

          # Child collection - nil means not loaded (default).
          # Callers must construct collection value objects explicitly via .from().
          attribute :submission_requirements,
                    Types.Instance(Values::SubmissionRequirements).optional.default(nil)

          # Check if requirements are loaded
          def requirements_loaded? = !submission_requirements.nil?
        end
      end
    end
  end
end
