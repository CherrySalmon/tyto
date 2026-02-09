# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Tyto
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
      property :course_name, exec_context: :decorator
      property :location_name, exec_context: :decorator
      property :user_attendance_status, exec_context: :decorator

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

      def course_name
        represented.respond_to?(:course_name) ? represented.course_name : nil
      end

      def location_name
        represented.respond_to?(:location_name) ? represented.location_name : nil
      end

      def user_attendance_status
        represented.respond_to?(:user_attendance_status) ? represented.user_attendance_status : nil
      end
    end
  end
end
