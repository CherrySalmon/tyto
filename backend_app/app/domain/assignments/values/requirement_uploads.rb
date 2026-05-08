# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'
require_relative '../entities/requirement_upload'

module Tyto
  module Domain
    module Assignments
      module Values
        # Value object wrapping a typed collection of RequirementUpload entities.
        # Encapsulates query methods for requirement uploads.
        class RequirementUploads < Dry::Struct
          attribute :requirement_uploads, Types::Array.of(Entities::RequirementUpload)

          include Enumerable

          def each(&block) = requirement_uploads.each(&block)

          # Find an upload by requirement ID
          def find_by_requirement(requirement_id)
            requirement_uploads.find { |u| u.requirement_id == requirement_id }
          end

          # Collection queries
          def any? = requirement_uploads.any?
          def empty? = requirement_uploads.empty?
          def count = requirement_uploads.size
          def length = requirement_uploads.length
          def size = requirement_uploads.size
          def to_a = requirement_uploads.dup

          # Convenience constructor from array
          def self.from(upload_array)
            new(requirement_uploads: upload_array || [])
          end
        end
      end
    end
  end
end
