# frozen_string_literal: true

require_relative '../policies/event_policy'
require_relative '../../infrastructure/database/repositories/events'
require_relative '../../infrastructure/database/repositories/locations'

module Todo
  # Manages event requests
  class EventService
    # Custom error classes
    class ForbiddenError < StandardError; end
    class EventNotFoundError < StandardError; end
    class CourseNotFoundError < StandardError; end

    # Repository instances (can be injected for testing)
    def self.events_repository
      @events_repository ||= Repository::Events.new
    end

    def self.events_repository=(repo)
      @events_repository = repo
    end

    def self.locations_repository
      @locations_repository ||= Repository::Locations.new
    end

    def self.locations_repository=(repo)
      @locations_repository = repo
    end

    # Lists course's events, if authorized
    # Returns domain entities converted to hashes for API compatibility
    def self.list(requestor, course_id)
      course_id = course_id.to_i
      find_course(course_id) # Verify course exists
      verify_policy(requestor, :view, course_id)

      entities = events_repository.find_by_course(course_id)
      entities.map { |entity| entity_to_hash(entity) }
    end

    # Creates a new event, if authorized
    def self.create(requestor, event_data, course_id)
      course_id = course_id.to_i
      find_course(course_id) # Verify course exists
      verify_policy(requestor, :create, course_id)

      # Normalize incoming times to UTC Time objects
      start_time = parse_time(event_data['start_at'])
      end_time = parse_time(event_data['end_at'])

      entity = Entity::Event.new(
        id: nil,
        course_id:,
        location_id: event_data['location_id'].to_i,
        name: event_data['name'],
        start_at: start_time,
        end_at: end_time,
        created_at: nil,
        updated_at: nil
      )

      created = events_repository.create(entity)
      entity_to_hash(created)
    end

    # Find events active at given time for user's courses
    def self.find(requestor, time)
      course_ids = AccountCourse.where(account_id: requestor['account_id']).select_map(:course_id)
      entities = events_repository.find_active_at(course_ids, time)
      entities.map { |entity| entity_to_hash(entity) }
    end

    # Update an existing event
    def self.update(requestor, event_id, course_id, event_data)
      event_id = event_id.to_i
      course_id = course_id.to_i
      verify_policy(requestor, :update, course_id)

      existing = events_repository.find_id(event_id)
      raise EventNotFoundError, "Event with ID #{event_id} not found" unless existing

      # Build updated entity with new values
      updated_entity = existing.new(
        location_id: event_data['location_id'] ? event_data['location_id'].to_i : existing.location_id,
        name: event_data['name'] || existing.name,
        start_at: event_data['start_at'] ? parse_time(event_data['start_at']) : existing.start_at,
        end_at: event_data['end_at'] ? parse_time(event_data['end_at']) : existing.end_at
      )

      result = events_repository.update(updated_entity)
      entity_to_hash(result)
    end

    # Remove an event
    def self.remove_event(requestor, event_id, course_id)
      event_id = event_id.to_i
      course_id = course_id.to_i
      verify_policy(requestor, :delete, course_id)
      events_repository.delete(event_id)
    end

    # Convert domain entity to hash for API compatibility
    # Note: This is a temporary bridge during migration. Eventually,
    # representers will handle serialization in the presentation layer.
    def self.entity_to_hash(entity)
      location = locations_repository.find_id(entity.location_id)

      {
        id: entity.id,
        course_id: entity.course_id,
        location_id: entity.location_id,
        name: entity.name,
        start_at: entity.start_at&.utc&.iso8601,
        end_at: entity.end_at&.utc&.iso8601,
        longitude: location&.longitude,
        latitude: location&.latitude
      }
    end

    private_class_method def self.find_course(course_id)
      Course.first(id: course_id) || raise(CourseNotFoundError, "Course with ID #{course_id} not found.")
    end

    private_class_method def self.parse_time(time_value)
      return nil unless time_value

      time_value.is_a?(Time) ? time_value.utc : Time.parse(time_value.to_s).utc
    end

    # Checks authorization for the requested action
    private_class_method def self.verify_policy(requestor, action = nil, course_id = nil)
      course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id:).map do |role|
        role.role.name
      end
      policy = EventPolicy.new(requestor, course_roles)
      action_check = action ? policy.send("can_#{action}?") : true
      raise(ForbiddenError, 'You have no access to perform this action.') unless action_check

      requestor
    end
  end
end
