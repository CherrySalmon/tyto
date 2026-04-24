# frozen_string_literal: true

require_relative '../../types'
require_relative '../../shared/values/time_range'
require_relative '../../shared/values/null_time_range'

module Tyto
  module Domain
    module Courses
      module Entities
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

          # Construct and validate the time_range up front, delegating the
          # cross-field invariant to Value::TimeRange (single source of truth).
          # Raises ArgumentError with TimeRange's user-facing message on bad input.
          def self.new(attributes)
            instance = super
            instance.time_range # triggers TimeRange.new invariant when both times present
            instance
          end

          # Returns a TimeRange value object, or NullTimeRange if dates are missing.
          # Uses Null Object pattern to eliminate nil checks in delegating methods.
          # Memoized — TimeRange is immutable and entity state is frozen at construction.
          def time_range
            @time_range ||= start_at && end_at ? Value::TimeRange.new(start_at:, end_at:) : Value::NullTimeRange.new
          end

          # Delegates to time_range (no guards needed - Null Object handles it)
          def duration = time_range.duration
          def active?(at: Time.now) = time_range.active?(at:)
          def upcoming?(at: Time.now) = time_range.upcoming?(at:)
          def ended?(at: Time.now) = time_range.ended?(at:)
        end
      end
    end
  end
end
