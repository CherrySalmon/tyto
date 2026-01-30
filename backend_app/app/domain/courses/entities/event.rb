# frozen_string_literal: true

require_relative '../../types'
require_relative '../../shared/values/time_range'
require_relative '../../shared/values/null_time_range'

module Tyto
  module Entity
    # Event entity within the Courses bounded context.
    # Events belong to a Course and have a Location.
    # Pure domain object with no infrastructure dependencies.
    # Immutable - updates create new instances via `new()`.
    class Event < Dry::Struct
      attribute :id, Types::Integer.optional
      attribute :course_id, Types::Integer
      attribute :location_id, Types::Integer
      attribute :name, Types::EventName
      attribute :start_at, Types::Time.optional
      attribute :end_at, Types::Time.optional
      attribute :created_at, Types::Time.optional
      attribute :updated_at, Types::Time.optional

      # Returns a TimeRange value object, or NullTimeRange if dates are missing.
      # Uses Null Object pattern to eliminate nil checks in delegating methods.
      def time_range
        return Value::NullTimeRange.new unless start_at && end_at

        Value::TimeRange.new(start_at:, end_at:)
      end

      # Delegates to time_range (no guards needed - Null Object handles it)
      def duration = time_range.duration
      def active?(at: Time.now) = time_range.active?(at:)
      def upcoming?(at: Time.now) = time_range.upcoming?(at:)
      def ended?(at: Time.now) = time_range.ended?(at:)
    end
  end
end
