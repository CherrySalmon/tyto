# frozen_string_literal: true

require_relative '../../../domain/courses/entities/location'

module Todo
  module Repository
    # Repository for Location entities.
    # Maps between ORM records and domain entities.
    class Locations
      # Find a location by ID
      # @param id [Integer] the location ID
      # @return [Entity::Location, nil] the domain entity or nil if not found
      def find_id(id)
        orm_record = Todo::Location[id]
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find all locations for a course
      # @param course_id [Integer] the course ID
      # @return [Array<Entity::Location>] array of domain entities
      def find_by_course(course_id)
        Todo::Location
          .where(course_id:)
          .order(:name)
          .all
          .map { |record| rebuild_entity(record) }
      end

      # Find all locations
      # @return [Array<Entity::Location>] array of domain entities
      def find_all
        Todo::Location.all.map { |record| rebuild_entity(record) }
      end

      # Create a new location from a domain entity
      # @param entity [Entity::Location] the domain entity to persist
      # @return [Entity::Location] the persisted entity with ID
      def create(entity)
        orm_record = Todo::Location.create(
          course_id: entity.course_id,
          name: entity.name,
          longitude: entity.longitude,
          latitude: entity.latitude
        )

        rebuild_entity(orm_record)
      end

      # Update an existing location from a domain entity
      # @param entity [Entity::Location] the domain entity with updates
      # @return [Entity::Location] the updated entity
      def update(entity)
        orm_record = Todo::Location[entity.id]
        raise "Location not found: #{entity.id}" unless orm_record

        orm_record.update(
          name: entity.name,
          longitude: entity.longitude,
          latitude: entity.latitude
        )

        rebuild_entity(orm_record.refresh)
      end

      # Delete a location by ID
      # @param id [Integer] the location ID
      # @return [Boolean] true if deleted
      def delete(id)
        orm_record = Todo::Location[id]
        return false unless orm_record

        orm_record.destroy
        true
      end

      # Check if a location has associated events
      # @param id [Integer] the location ID
      # @return [Boolean] true if location has events
      def has_events?(id)
        orm_record = Todo::Location[id]
        return false unless orm_record

        orm_record.events.any?
      end

      private

      # Rebuild a domain entity from an ORM record
      # @param orm_record [Todo::Location] the Sequel model instance
      # @return [Entity::Location] the domain entity
      def rebuild_entity(orm_record)
        Entity::Location.new(
          id: orm_record.id,
          course_id: orm_record.course_id,
          name: orm_record.name,
          longitude: orm_record.longitude,
          latitude: orm_record.latitude,
          created_at: orm_record.created_at,
          updated_at: orm_record.updated_at
        )
      end
    end
  end
end
