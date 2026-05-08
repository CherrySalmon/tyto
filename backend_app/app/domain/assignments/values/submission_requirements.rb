# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'
require_relative '../entities/submission_requirement'

module Tyto
  module Domain
    module Assignments
      module Values
        # Value object wrapping a typed collection of SubmissionRequirement entities.
        # Encapsulates query methods for submission requirements.
        class SubmissionRequirements < Dry::Struct
          attribute :submission_requirements, Types::Array.of(Entities::SubmissionRequirement)

          include Enumerable

          def each(&block) = submission_requirements.each(&block)

          # Find a requirement by ID
          def find(requirement_id)
            submission_requirements.find { |r| r.id == requirement_id }
          end

          # Collection queries
          def any? = submission_requirements.any?
          def empty? = submission_requirements.empty?
          def count = submission_requirements.size
          def length = submission_requirements.length
          def size = submission_requirements.size
          def to_a = submission_requirements.dup

          # Convenience constructor from array
          def self.from(requirement_array)
            new(submission_requirements: requirement_array || [])
          end
        end
      end
    end
  end
end
