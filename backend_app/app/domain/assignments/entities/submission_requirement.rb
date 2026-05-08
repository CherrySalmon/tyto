# frozen_string_literal: true

require_relative '../../types'

module Tyto
  module Domain
    module Assignments
      module Entities
        # SubmissionRequirement child entity within the Assignment aggregate.
        # Defines one required piece of a submission (e.g., "R Markdown source" or "GitHub repo link").
        # Loaded/saved through the Assignment aggregate root.
        # Pure domain object with no infrastructure dependencies.
        # Immutable - updates create new instances via `new()`.
        class SubmissionRequirement < Dry::Struct
          attribute :id, Types::Integer.optional
          attribute :assignment_id, Types::Integer
          attribute :submission_format, Types::RequirementType
          attribute :description, Types::String
          attribute :allowed_types, Types::String.optional
          attribute :sort_order, Types::Integer
          attribute :created_at, Types::Time.optional
          attribute :updated_at, Types::Time.optional
        end
      end
    end
  end
end
