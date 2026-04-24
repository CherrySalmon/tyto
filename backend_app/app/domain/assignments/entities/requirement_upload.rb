# frozen_string_literal: true

require_relative '../../types'

module Tyto
  module Domain
    module Assignments
      module Entities
        # RequirementUpload child entity within the Submission aggregate.
        # Represents one fulfilled submission requirement (file or URL stored in S3).
        # Loaded/saved through the Submission aggregate root.
        # Pure domain object with no infrastructure dependencies.
        # Immutable - updates create new instances via `new()`.
        class RequirementUpload < Dry::Struct
          attribute :id, Types::Integer.optional
          attribute :submission_id, Types::Integer
          attribute :requirement_id, Types::Integer
          attribute :content, Types::String
          attribute :filename, Types::String.optional.default(nil)
          attribute :content_type, Types::String.optional.default(nil)
          attribute :file_size, Types::Integer.optional.default(nil)
          attribute :created_at, Types::Time.optional
          attribute :updated_at, Types::Time.optional
        end
      end
    end
  end
end
