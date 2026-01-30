# frozen_string_literal: true

require_relative '../../../domain/courses/entities/event'

module Todo
  module Repository
    # Repository for Event entities.
    # Maps between ORM records and domain entities.
    class Events
      # Find an event by ID
      # @param id [Integer] the event ID
      # @return [Entity::Event, nil] the domain entity or nil if not found
      def find_id(id)
        orm_record = Todo::Event[id]
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find all events for a course, ordered by start time
      # @param course_id [Integer] the course ID
      # @return [Array<Entity::Event>] array of domain entities
      def find_by_course(course_id)
        Todo::Event
          .where(course_id:)
          .order(:start_at)
          .all
          .map { |record| rebuild_entity(record) }
      end

      # Find all events
      # @return [Array<Entity::Event>] array of domain entities
      def find_all
        Todo::Event.all.map { |record| rebuild_entity(record) }
      end

      # Find events active at a given time for specified course IDs
      # @param course_ids [Array<Integer>] list of course IDs to filter
      # @param time [Time] the time to check
      # @return [Array<Entity::Event>] array of active domain entities
      def find_active_at(course_ids, time)
        Todo::Event
          .where { start_at <= time }
          .where { end_at >= time }
          .where(course_id: course_ids)
          .all
          .map { |record| rebuild_entity(record) }
      end

      # Create a new event from a domain entity
      # @param entity [Entity::Event] the domain entity to persist
      # @return [Entity::Event] the persisted entity with ID
      def create(entity)
        orm_record = Todo::Event.find_or_create(
          course_id: entity.course_id,
          location_id: entity.location_id,
          name: entity.name,
          start_at: entity.start_at&.utc,
          end_at: entity.end_at&.utc
        )

        rebuild_entity(orm_record)
      end

      # Update an existing event from a domain entity
      # @param entity [Entity::Event] the domain entity with updates
      # @return [Entity::Event] the updated entity
      def update(entity)
        orm_record = Todo::Event[entity.id]
        raise "Event not found: #{entity.id}" unless orm_record

        orm_record.update(
          location_id: entity.location_id,
          name: entity.name,
          start_at: entity.start_at&.utc,
          end_at: entity.end_at&.utc
        )

        rebuild_entity(orm_record.refresh)
      end

      # Delete an event by ID
      # @param id [Integer] the event ID
      # @return [Boolean] true if deleted
      def delete(id)
        orm_record = Todo::Event[id]
        return false unless orm_record

        orm_record.destroy
        true
      end

      private

      # Rebuild a domain entity from an ORM record
      # @param orm_record [Todo::Event] the Sequel model instance
      # @return [Entity::Event] the domain entity
      def rebuild_entity(orm_record)
        Entity::Event.new(
          id: orm_record.id,
          course_id: orm_record.course_id,
          location_id: orm_record.location_id,
          name: orm_record.name,
          start_at: orm_record.start_at,
          end_at: orm_record.end_at,
          created_at: orm_record.created_at,
          updated_at: orm_record.updated_at
        )
      end
    end
  end
end
