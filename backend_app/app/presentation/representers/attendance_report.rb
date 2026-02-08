# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Tyto
  module Representer
    # Representer for AttendanceReport entity to JSON
    class AttendanceReport < Roar::Decorator
      include Roar::JSON

      property :course_name
      property :generated_at, exec_context: :decorator
      property :events, exec_context: :decorator
      property :student_records, exec_context: :decorator

      def generated_at
        represented.generated_at&.utc&.iso8601
      end

      def events
        represented.events.map { |e| { 'id' => e.id, 'name' => e.name } }
      end

      def student_records
        represented.student_records.map do |record|
          {
            'email' => record.email,
            'attend_sum' => record.attend_sum,
            'attend_percent' => record.attend_percent,
            'event_attendance' => record.event_attendance.transform_keys(&:to_s)
          }
        end
      end
    end
  end
end
