# frozen_string_literal: true

require_relative '../../types'

module Tyto
  module Value
    # Value object representing a time range with start and end times.
    # Immutable - updates create new instances via `new()`.
    class TimeRange < Dry::Struct
      attribute :start_at, Types::Time
      attribute :end_at, Types::Time

      # Validate invariant: end must be after start
      def self.new(attributes)
        if attributes[:end_at] && attributes[:start_at] && attributes[:end_at] <= attributes[:start_at]
          raise ArgumentError, 'end_at must be after start_at'
        end

        super
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
