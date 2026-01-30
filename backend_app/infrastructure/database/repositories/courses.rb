# frozen_string_literal: true

require_relative '../../../domain/courses/entities/course'

module Todo
  module Repository
    # Repository for Course aggregate root.
    # Maps between ORM records and domain entities.
    class Courses
      # Find a course by ID
      # @param id [Integer] the course ID
      # @return [Entity::Course, nil] the domain entity or nil if not found
      def find_id(id)
        orm_record = Todo::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find all courses
      # @return [Array<Entity::Course>] array of domain entities
      def find_all
        Todo::Course.all.map { |record| rebuild_entity(record) }
      end

      # Create a new course from a domain entity
      # @param entity [Entity::Course] the domain entity to persist
      # @return [Entity::Course] the persisted entity with ID
      def create(entity)
        orm_record = Todo::Course.create(
          name: entity.name,
          logo: entity.logo,
          start_at: entity.start_at,
          end_at: entity.end_at
        )

        rebuild_entity(orm_record)
      end

      # Update an existing course from a domain entity
      # @param entity [Entity::Course] the domain entity with updates
      # @return [Entity::Course] the updated entity
      def update(entity)
        orm_record = Todo::Course[entity.id]
        raise "Course not found: #{entity.id}" unless orm_record

        orm_record.update(
          name: entity.name,
          logo: entity.logo,
          start_at: entity.start_at,
          end_at: entity.end_at
        )

        rebuild_entity(orm_record.refresh)
      end

      # Delete a course by ID
      # @param id [Integer] the course ID
      # @return [Boolean] true if deleted
      def delete(id)
        orm_record = Todo::Course[id]
        return false unless orm_record

        orm_record.destroy
        true
      end

      private

      # Rebuild a domain entity from an ORM record
      # @param orm_record [Todo::Course] the Sequel model instance
      # @return [Entity::Course] the domain entity
      def rebuild_entity(orm_record)
        Entity::Course.new(
          id: orm_record.id,
          name: orm_record.name,
          logo: orm_record.logo,
          start_at: orm_record.start_at,
          end_at: orm_record.end_at,
          created_at: orm_record.created_at,
          updated_at: orm_record.updated_at
        )
      end
    end
  end
end
