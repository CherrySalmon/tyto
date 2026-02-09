# frozen_string_literal: true

require 'set'

module Tyto
  module Domain
    module Attendance
      module Values
        # Value object representing the attendance register for a course.
        # Records which students attended which events for fast lookup.
        class AttendanceRegister
          def initialize(attendances:)
            @index = Hash.new { |h, k| h[k] = Set.new }
            attendances.each { |a| @index[a.account_id].add(a.event_id) }
            @index.freeze
          end

          def attended?(account_id, event_id)
            @index.key?(account_id) && @index[account_id].include?(event_id)
          end
        end
      end
    end
  end
end
