# frozen_string_literal: true

module Tyto
  module Domain
    module Attendance
      module Values
        # Value object representing a single participant's attendance status
        # at a specific event.
        ParticipantAttendance = Data.define(:account_id, :name, :email, :attended)
      end
    end
  end
end
