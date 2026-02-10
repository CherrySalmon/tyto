# frozen_string_literal: true

module Tyto
  module Policy
    # Domain policy: "Attendance is valid when the student is at the right place
    # at the right time."
    # Actor-agnostic — a domain expert would articulate these rules without
    # mentioning roles. The decision of *who* must comply is an application-level
    # concern handled by the service.
    class AttendanceEligibility
      MAX_DISTANCE_KM = 0.055 # ~55 meters

      # Check if an attendance attempt is eligible.
      # @param attendance [Domain::Attendance::Entities::Attendance] the attendance with check-in coordinates
      # @param event [Domain::Courses::Entities::Event] the event being attended
      # @param location [Domain::Courses::Entities::Location, nil] the event's location
      # @param time [Time] the time of the attendance attempt
      # @return [Symbol, nil] nil if eligible, or a symbol indicating the failure reason
      def self.check(attendance:, event:, location:, time: Time.now)
        return :time_window unless active_event?(event, time)
        return :proximity unless within_range?(attendance, location)

        nil
      end

      # Specific policy checks below:
      #   - return true if policy is irrelevant (e.g., criteria not defined)
      #   - call value object's check predicate on relevant criteria

      def self.active_event?(event, time)
        return true unless event.time_range.present?

        event.active?(at: time)
      end

      def self.within_range?(attendance, location)
        return true unless location&.has_coordinates?

        attendance.within_range?(location, max_distance_km: MAX_DISTANCE_KM)
      end

      private_class_method :active_event?, :within_range?
    end
  end
end
