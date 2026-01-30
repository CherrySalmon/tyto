# frozen_string_literal: true

require_relative '../../types'
require_relative '../../shared/values/time_range'

module Todo
  module Entity
    # Course aggregate root entity.
    # Pure domain object with no infrastructure dependencies.
    # Immutable - updates create new instances via `new()`.
    class Course < Dry::Struct
      attribute :id, Types::Integer.optional
      attribute :name, Types::CourseName
      attribute :logo, Types::String.optional
      attribute :start_at, Types::Time.optional
      attribute :end_at, Types::Time.optional
      attribute :created_at, Types::Time.optional
      attribute :updated_at, Types::Time.optional

      # Returns a TimeRange value object if both start and end times exist
      def time_range
        return nil unless start_at && end_at

        Value::TimeRange.new(start_at:, end_at:)
      end

      # Duration in seconds (delegates to time_range)
      def duration
        time_range&.duration
      end

      # Is the course currently active?
      def active?(at: Time.now)
        return false unless time_range

        time_range.active?(at:)
      end

      # Is the course in the future?
      def upcoming?(at: Time.now)
        return false unless time_range

        time_range.upcoming?(at:)
      end

      # Has the course ended?
      def ended?(at: Time.now)
        return false unless time_range

        time_range.ended?(at:)
      end

      # Is this a new (unpersisted) course?
      def new_record?
        id.nil?
      end

      # Convert to hash suitable for persistence (excludes nil id for new records)
      def to_persistence_hash
        hash = { name:, logo:, start_at:, end_at: }
        hash[:id] = id unless new_record?
        hash
      end
    end
  end
end
