# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Todo
  module Representer
    # Representer for Attendance entity to JSON
    class Attendance < Roar::Decorator
      include Roar::JSON

      property :id
      property :account_id
      property :course_id
      property :event_id
      property :name
      property :longitude
      property :latitude
      property :created_at, exec_context: :decorator
      property :updated_at, exec_context: :decorator

      def created_at
        represented.created_at&.utc&.iso8601
      end

      def updated_at
        represented.updated_at&.utc&.iso8601
      end
    end

    # Representer for collection of Attendance entities
    class AttendancesList
      def self.from_entities(entities)
        new(entities)
      end

      def initialize(entities)
        @entities = entities
      end

      def to_array
        @entities.map { |entity| Attendance.new(entity).to_hash }
      end
    end
  end
end
