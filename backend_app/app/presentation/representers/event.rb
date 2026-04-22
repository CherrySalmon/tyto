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
      property :longitude
      property :latitude
      property :course_name
      property :location_name
      property :user_attendance_status, exec_context: :decorator

      def start_at
        represented.start_at&.utc&.iso8601
      end

      def end_at
        represented.end_at&.utc&.iso8601
      end

      # Only ActiveEventDetails (FindActiveEvents) carries user_attendance_status;
      # EventDetails (everywhere else) does not.
      def user_attendance_status
        represented.respond_to?(:user_attendance_status) ? represented.user_attendance_status : nil
      end
    end
  end
end
