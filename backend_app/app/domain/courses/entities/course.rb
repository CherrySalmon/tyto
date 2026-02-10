# frozen_string_literal: true

require_relative '../../types'
require_relative '../../shared/values/time_range'
require_relative '../../shared/values/null_time_range'
require_relative '../values/events'
require_relative '../values/locations'
require_relative '../values/enrollments'

module Tyto
  module Domain
    module Courses
      module Entities
        # Course aggregate root entity.
        # Pure domain object with no infrastructure dependencies.
        # Immutable - updates create new instances via `new()`.
        #
        # Child collections use typed collection value objects:
        #   nil  = not loaded (calling methods on nil raises NoMethodError)
        #   collection = loaded (Events, Locations, Enrollments)
        # Callers must construct collection objects explicitly via .from().
        class Course < Dry::Struct

          attribute :id, Types::Integer.optional
          attribute :name, Types::CourseName
          attribute :logo, Types::String.optional
          attribute :start_at, Types::Time.optional
          attribute :end_at, Types::Time.optional
          attribute :created_at, Types::Time.optional
          attribute :updated_at, Types::Time.optional

          # Child collections - nil means not loaded (default).
          # Callers must construct collection value objects explicitly via .from().
          attribute :events, Types.Instance(Values::Events).optional.default(nil)
          attribute :locations, Types.Instance(Values::Locations).optional.default(nil)
          attribute :enrollments, Types.Instance(Values::Enrollments).optional.default(nil)

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
          def enrollments_loaded? = !enrollments.nil?

          # Find an event by ID within this course's events
          # Delegates to Events
          def find_event(event_id)
            events.find(event_id)
          end

          # Find a location by ID within this course's locations
          # Delegates to Locations
          def find_location(location_id)
            locations.find(location_id)
          end

          # Count of events — delegates to Events
          def event_count
            events.count
          end

          # Count of locations — delegates to Locations
          def location_count
            locations.count
          end

          # Find an enrollment by account ID — delegates to Enrollments
          def find_enrollment(account_id)
            enrollments.find_by_account(account_id)
          end

          # Count of enrollments — delegates to Enrollments
          def enrollment_count
            enrollments.count
          end

          # Get all enrollments with a specific role — delegates to Enrollments
          def enrollments_with_role(role_name)
            enrollments.with_role(role_name)
          end

          # Get all teaching staff — delegates to Enrollments
          def teaching_staff
            enrollments.teaching_staff
          end

          # Get all students — delegates to Enrollments
          def students
            enrollments.students
          end
        end
      end
    end
  end
end
