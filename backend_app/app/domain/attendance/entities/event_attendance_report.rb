# frozen_string_literal: true

require_relative '../values/participant_attendance'

module Tyto
  module Domain
    module Attendance
      module Entities
        # Domain entity representing all participants' attendance at an event,
        # along with the requestor's attendance management permissions.
        # Builds ParticipantAttendance value objects from enrollments and
        # attendance records.
        class EventAttendanceReport
          attr_reader :participants, :policies

          def initialize(enrollments:, attendances:, policies:)
            @policies = policies
            @participants = build_participants(enrollments, attendances)
          end

          def to_h
            {
              participants: participants.map(&:to_h),
              policies:
            }
          end

          private

          def build_participants(enrollments, attendances)
            attended_account_ids = attendances.map(&:account_id).to_set

            enrollments.select(&:student?).map do |enrollment|
              Values::ParticipantAttendance.new(
                account_id: enrollment.account_id,
                name: enrollment.participant.name,
                email: enrollment.participant.email,
                attended: attended_account_ids.include?(enrollment.account_id)
              )
            end
          end
        end
      end
    end
  end
end
