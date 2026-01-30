# frozen_string_literal: true

require_relative '../../../domain/attendance/entities/attendance'

module Todo
  module Repository
    # Repository for Attendance entities.
    # Maps between ORM records and domain entities.
    class Attendances
      # Find an attendance by ID
      # @param id [Integer] the attendance ID
      # @return [Entity::Attendance, nil] the domain entity or nil if not found
      def find_id(id)
        orm_record = Todo::Attendance[id]
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find all attendances for a course
      # @param course_id [Integer] the course ID
      # @return [Array<Entity::Attendance>] array of domain entities
      def find_by_course(course_id)
        Todo::Attendance
          .where(course_id:)
          .order(:created_at)
          .all
          .map { |record| rebuild_entity(record) }
      end

      # Find all attendances for an event
      # @param event_id [Integer] the event ID
      # @return [Array<Entity::Attendance>] array of domain entities
      def find_by_event(event_id)
        Todo::Attendance
          .where(event_id:)
          .order(:created_at)
          .all
          .map { |record| rebuild_entity(record) }
      end

      # Find all attendances for an account in a course
      # @param account_id [Integer] the account ID
      # @param course_id [Integer] the course ID
      # @return [Array<Entity::Attendance>] array of domain entities
      def find_by_account_course(account_id, course_id)
        Todo::Attendance
          .where(account_id:, course_id:)
          .order(:created_at)
          .all
          .map { |record| rebuild_entity(record) }
      end

      # Find attendance for an account at a specific event
      # @param account_id [Integer] the account ID
      # @param event_id [Integer] the event ID
      # @return [Entity::Attendance, nil] the domain entity or nil
      def find_by_account_event(account_id, event_id)
        orm_record = Todo::Attendance.first(account_id:, event_id:)
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find all attendances
      # @return [Array<Entity::Attendance>] array of domain entities
      def find_all
        Todo::Attendance.all.map { |record| rebuild_entity(record) }
      end

      # Create a new attendance from a domain entity
      # @param entity [Entity::Attendance] the domain entity to persist
      # @return [Entity::Attendance] the persisted entity with ID
      def create(entity)
        orm_record = Todo::Attendance.find_or_create(
          account_id: entity.account_id,
          course_id: entity.course_id,
          event_id: entity.event_id,
          role_id: entity.role_id,
          name: entity.name,
          longitude: entity.longitude,
          latitude: entity.latitude
        )

        rebuild_entity(orm_record)
      end

      # Delete an attendance by ID
      # @param id [Integer] the attendance ID
      # @return [Boolean] true if deleted
      def delete(id)
        orm_record = Todo::Attendance[id]
        return false unless orm_record

        orm_record.destroy
        true
      end

      private

      # Rebuild a domain entity from an ORM record
      # @param orm_record [Todo::Attendance] the Sequel model instance
      # @return [Entity::Attendance] the domain entity
      def rebuild_entity(orm_record)
        Entity::Attendance.new(
          id: orm_record.id,
          account_id: orm_record.account_id,
          course_id: orm_record.course_id,
          event_id: orm_record.event_id,
          role_id: orm_record.role_id,
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
