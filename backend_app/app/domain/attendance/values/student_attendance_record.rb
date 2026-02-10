# frozen_string_literal: true

module Tyto
  module Domain
    module Attendance
      module Values
        # Value object representing a single student's attendance statistics
        # within an attendance report. Computes statistics on demand from its
        # constructor dependencies.
        class StudentAttendanceRecord
          attr_reader :email

          def initialize(enrollment:, events:, register:)
            @email = enrollment.participant.email
            @account_id = enrollment.account_id
            @events = events
            @register = register
          end

          def event_attendance
            @event_attendance ||= @events.each_with_object({}) do |event, hash|
              hash[event.id] = @register.attended?(@account_id, event.id) ? 1 : 0
            end
          end

          def attend_sum
            @attend_sum ||= event_attendance.values.sum
          end

          def attend_percent
            @attend_percent ||= @events.empty? ? 0.0 : (attend_sum.to_f / @events.length * 100).round(2)
          end

          def ==(other)
            other.is_a?(self.class) &&
              email == other.email &&
              event_attendance == other.event_attendance
          end
          alias eql? ==

          def hash
            [email, event_attendance].hash
          end
        end
      end
    end
  end
end
