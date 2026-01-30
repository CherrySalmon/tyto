# frozen_string_literal: true

require_relative '../../types'
require_relative '../../shared/values/time_range'
require_relative '../../shared/values/null_time_range'

module Todo
  module Entity
    # Course aggregate root entity.
    # Pure domain object with no infrastructure dependencies.
    # Immutable - updates create new instances via `new()`.
    #
    # Child collections (events, locations) follow this convention:
    #   nil = not loaded (methods requiring them will raise)
    #   []  = loaded but empty
    class Course < Dry::Struct
      # Error raised when accessing children that weren't loaded
      class ChildrenNotLoadedError < StandardError; end

      attribute :id, Types::Integer.optional
      attribute :name, Types::CourseName
      attribute :logo, Types::String.optional
      attribute :start_at, Types::Time.optional
      attribute :end_at, Types::Time.optional
      attribute :created_at, Types::Time.optional
      attribute :updated_at, Types::Time.optional

      # Child collections - nil means not loaded (default)
      attribute :events, Types::Array.optional.default(nil)
      attribute :locations, Types::Array.optional.default(nil)

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

      # Check if children are loaded
      def events_loaded? = !events.nil?
      def locations_loaded? = !locations.nil?

      # Find an event by ID within this course's events
      # @raise [ChildrenNotLoadedError] if events weren't loaded
      def find_event(event_id)
        require_events_loaded!
        events.find { |e| e.id == event_id }
      end

      # Find a location by ID within this course's locations
      # @raise [ChildrenNotLoadedError] if locations weren't loaded
      def find_location(location_id)
        require_locations_loaded!
        locations.find { |l| l.id == location_id }
      end

      # Count of events (raises if not loaded)
      def event_count
        require_events_loaded!
        events.size
      end

      # Count of locations (raises if not loaded)
      def location_count
        require_locations_loaded!
        locations.size
      end

      private

      def require_events_loaded!
        raise ChildrenNotLoadedError, 'Events not loaded for this course' if events.nil?
      end

      def require_locations_loaded!
        raise ChildrenNotLoadedError, 'Locations not loaded for this course' if locations.nil?
      end
    end
  end
end
