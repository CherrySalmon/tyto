# frozen_string_literal: true

require 'ostruct'
require 'roar/decorator'
require 'roar/json'

module Tyto
  module Representer
    # Serializes RequirementUpload entity to JSON
    class RequirementUploadRepr < Roar::Decorator
      include Roar::JSON

      property :id
      property :submission_id
      property :requirement_id
      property :content
      property :filename
      property :content_type
      property :file_size
      property :created_at, exec_context: :decorator
      property :updated_at, exec_context: :decorator

      def created_at
        represented.created_at&.utc&.iso8601
      end

      def updated_at
        represented.updated_at&.utc&.iso8601
      end
    end

    # Serializes Submitter value object (student identity summary on a submission)
    class SubmitterRepr < Roar::Decorator
      include Roar::JSON

      property :account_id
      property :name
      property :email
    end

    # Serializes Submission domain entity to JSON
    class Submission < Roar::Decorator
      include Roar::JSON

      property :id
      property :assignment_id
      property :account_id
      property :submitted_at, exec_context: :decorator
      property :created_at, exec_context: :decorator
      property :updated_at, exec_context: :decorator
      collection :requirement_uploads, extend: RequirementUploadRepr,
                                       exec_context: :decorator
      property :submitter, extend: SubmitterRepr, exec_context: :decorator
      property :policies, exec_context: :decorator

      def submitted_at
        represented.submitted_at&.utc&.iso8601
      end

      def created_at
        represented.created_at&.utc&.iso8601
      end

      def updated_at
        represented.updated_at&.utc&.iso8601
      end

      def requirement_uploads
        return [] unless represented.uploads_loaded?

        represented.requirement_uploads.to_a
      end

      def submitter
        represented.submitter
      end

      def policies
        represented.respond_to?(:policies) ? represented.policies : nil
      end
    end

    # Serializes a collection of Submission entities to JSON array
    class SubmissionsList < Roar::Decorator
      include Roar::JSON

      collection :entries, extend: Representer::Submission, class: OpenStruct

      def self.from_entities(submissions)
        wrapper = OpenStruct.new(entries: submissions)
        new(wrapper)
      end

      def to_array
        ::JSON.parse(to_json)['entries']
      end
    end
  end
end
