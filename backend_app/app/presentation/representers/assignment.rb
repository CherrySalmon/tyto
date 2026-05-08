# frozen_string_literal: true

require 'ostruct'
require 'roar/decorator'
require 'roar/json'

module Tyto
  module Representer
    # Serializes SubmissionRequirement entity to JSON
    class SubmissionRequirementRepr < Roar::Decorator
      include Roar::JSON

      property :id
      property :assignment_id
      property :submission_format
      property :description
      property :allowed_types
      property :sort_order
    end

    # Serializes the LinkedEvent value object (event summary attached to an Assignment)
    class LinkedEventRepr < Roar::Decorator
      include Roar::JSON

      property :id
      property :name
      property :start_at, exec_context: :decorator
      property :end_at, exec_context: :decorator

      def start_at
        represented.start_at&.utc&.iso8601
      end

      def end_at
        represented.end_at&.utc&.iso8601
      end
    end

    # Serializes Assignment domain entity to JSON
    class Assignment < Roar::Decorator
      include Roar::JSON

      property :id
      property :course_id
      property :event_id
      property :title
      property :description
      property :status
      property :due_at, exec_context: :decorator
      property :allow_late_resubmit
      property :created_at, exec_context: :decorator
      property :updated_at, exec_context: :decorator
      collection :submission_requirements, extend: SubmissionRequirementRepr,
                                           exec_context: :decorator
      property :linked_event, extend: LinkedEventRepr, exec_context: :decorator
      property :policies, exec_context: :decorator

      def due_at
        represented.due_at&.utc&.iso8601
      end

      def created_at
        represented.created_at&.utc&.iso8601
      end

      def updated_at
        represented.updated_at&.utc&.iso8601
      end

      def submission_requirements
        return [] unless represented.requirements_loaded?

        represented.submission_requirements.to_a
      end

      def linked_event
        represented.linked_event
      end

      def policies
        represented.respond_to?(:policies) ? represented.policies : nil
      end
    end

    # Serializes a collection of Assignment entities to JSON array
    class AssignmentsList < Roar::Decorator
      include Roar::JSON

      collection :entries, extend: Representer::Assignment, class: OpenStruct

      def self.from_entities(assignments)
        wrapper = OpenStruct.new(entries: assignments)
        new(wrapper)
      end

      def to_array
        ::JSON.parse(to_json)['entries']
      end
    end
  end
end
