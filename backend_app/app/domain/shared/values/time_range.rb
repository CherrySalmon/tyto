# frozen_string_literal: true

require 'time'
require_relative '../../types'

module Tyto
  module Value
    # Value object representing a time range with start and end times.
    # Immutable - updates create new instances via `new()`.
    class TimeRange < Dry::Struct
      attribute :start_at, Types::Time
      attribute :end_at, Types::Time

      # Validate cross-field invariant: end must be after start.
      # (Individual attribute types handled by dry-struct via Types::Time.)
      def self.new(attributes)
        if attributes[:end_at] && attributes[:start_at] && attributes[:end_at] <= attributes[:start_at]
          raise ArgumentError, 'End time must be after start time'
        end

        super
      end

      # Factory: parse start and end from raw values (String | Time | nil) and
      # return a TimeRange. Handles the parts dry-struct can't: string coercion
      # and the nil-vs-parsed distinction. Cross-field validation delegates to new().
      # Raises ArgumentError with user-facing messages for application-layer translation.
      def self.parse(start_raw, end_raw)
        start_time = parse_time(start_raw)
        end_time = parse_time(end_raw)
        raise ArgumentError, 'Start time is required' if start_time.nil?
        raise ArgumentError, 'End time is required' if end_time.nil?

        new(start_at: start_time, end_at: end_time)
      end

      # Parse a raw value (String | Time | nil) into a UTC Time, or nil on failure.
      def self.parse_time(raw)
        return nil unless raw

        raw.is_a?(::Time) ? raw.utc : ::Time.parse(raw.to_s).utc
      rescue ArgumentError
        nil
      end

      # Duration in seconds
      def duration
        end_at - start_at
      end

      # Duration in days
      def duration_days
        duration / (24 * 60 * 60)
      end

      # Is the current time within this range?
      def active?(at: Time.now)
        at >= start_at && at <= end_at
      end

      # Is this range in the future?
      def upcoming?(at: Time.now)
        start_at > at
      end

      # Has this range ended?
      def ended?(at: Time.now)
        end_at < at
      end

      # Does this range overlap with another?
      def overlaps?(other)
        start_at < other.end_at && end_at > other.start_at
      end

      # Does this range contain a specific time?
      def contains?(time)
        time >= start_at && time <= end_at
      end

      # Interface parity with NullTimeRange
      def null? = false
      def present? = true
    end
  end
end
