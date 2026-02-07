# frozen_string_literal: true

module Tyto
  module Policy
    # Domain policy: "Attendance must be within 55m of the event location."
    # Actor-agnostic — the threshold is a business rule a domain expert would articulate.
    # The decision of *who* must comply (e.g., students but not teachers) is an
    # application-level concern handled by the service.
    class AttendanceProximity
      MAX_DISTANCE_KM = 0.055 # ~55 meters

      # Check if attendance is within acceptable proximity of an event location.
      # @param attendance [Entity::Attendance] the attendance with check-in coordinates
      # @param event_location [Entity::Location, nil] the event's location
      # @return [Boolean] true if within range, or if event has no location to validate against
      def self.satisfied?(attendance, event_location)
        return true unless event_location&.has_coordinates?

        attendance.within_range?(event_location, max_distance_km: MAX_DISTANCE_KM)
      end
    end
  end
end
