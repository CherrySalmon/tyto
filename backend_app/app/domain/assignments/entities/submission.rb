# frozen_string_literal: true

require_relative '../../types'
require_relative '../values/requirement_uploads'
require_relative '../values/submitter'

module Tyto
  module Domain
    module Assignments
      module Entities
        # Submission aggregate root entity.
        # Represents a student's submission for an assignment.
        # One submission per student per assignment (overwrite model).
        # Pure domain object with no infrastructure dependencies.
        # Immutable - updates create new instances via `new()`.
        #
        # Child collection uses typed collection value object:
        #   nil  = not loaded (calling methods on nil raises NoMethodError)
        #   RequirementUploads = loaded
        # Callers must construct collection objects explicitly via .from().
        class Submission < Dry::Struct
          attribute :id, Types::Integer.optional
          attribute :assignment_id, Types::Integer
          attribute :account_id, Types::Integer
          attribute :submitted_at, Types::Time
          attribute :created_at, Types::Time.optional
          attribute :updated_at, Types::Time.optional

          # Child collection - nil means not loaded (default).
          # Callers must construct collection value objects explicitly via .from().
          attribute :requirement_uploads,
                    Types.Instance(Values::RequirementUploads).optional.default(nil)

          # Submitter summary — nil when not loaded. Used by staff views so
          # the frontend can show student name/email without an extra lookup.
          attribute :submitter,
                    Types.Instance(Values::Submitter).optional.default(nil)

          # Check if uploads are loaded
          def uploads_loaded? = !requirement_uploads.nil?
        end
      end
    end
  end
end
