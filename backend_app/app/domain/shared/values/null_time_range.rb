# frozen_string_literal: true

module Todo
  module Value
    # Null Object for TimeRange.
    # Represents a missing/undefined time range with safe default behavior.
    # Implements the same interface as TimeRange, returning sensible defaults.
    class NullTimeRange
      def start_at = nil
      def end_at = nil

      def duration = 0
      def duration_days = 0

      def active?(**) = false
      def upcoming?(**) = false
      def ended?(**) = false

      def overlaps?(_) = false
      def contains?(_) = false

      # Null objects are always equal to each other
      def ==(other)
        other.is_a?(NullTimeRange)
      end

      # For pattern matching and inspection
      def null? = true
      def present? = false
    end
  end
end
