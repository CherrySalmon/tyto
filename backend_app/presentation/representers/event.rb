# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Todo
  module Representer
    # Serializes Event domain entity to JSON
    class Event < Roar::Decorator
      include Roar::JSON

      property :id
      property :course_id
      property :location_id
      property :name
      property :start_at, exec_context: :decorator
      property :end_at, exec_context: :decorator
      property :longitude, exec_context: :decorator
      property :latitude, exec_context: :decorator

      def start_at
        represented.start_at&.utc&.iso8601
      end

      def end_at
        represented.end_at&.utc&.iso8601
      end

      # Location coordinates - requires location to be loaded
      def longitude
        represented.respond_to?(:longitude) ? represented.longitude : nil
      end

      def latitude
        represented.respond_to?(:latitude) ? represented.latitude : nil
      end
    end
  end
end
