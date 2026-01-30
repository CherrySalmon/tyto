# frozen_string_literal: true

require_relative '../../../domain/courses/entities/course'
require_relative '../../../domain/courses/entities/event'
require_relative '../../../domain/courses/entities/location'
require_relative '../../../domain/courses/entities/enrollment'

module Todo
  module Repository
    # Repository for Course aggregate root.
    # Maps between ORM records and domain entities.
    #
    # Loading conventions:
    #   find_id / find_all        - Course only (children = nil)
    #   find_with_events          - Course + events loaded
    #   find_with_locations       - Course + locations loaded
    #   find_with_enrollments     - Course + enrollments loaded
    #   find_full                 - Course + all children loaded
    class Courses
      # Find a course by ID (children not loaded)
      # @param id [Integer] the course ID
      # @return [Entity::Course, nil] the domain entity or nil if not found
      def find_id(id)
        orm_record = Todo::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find a course by ID with events loaded
      # @param id [Integer] the course ID
      # @return [Entity::Course, nil] the domain entity with events, or nil
      def find_with_events(id)
        orm_record = Todo::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_events: true)
      end

      # Find a course by ID with locations loaded
      # @param id [Integer] the course ID
      # @return [Entity::Course, nil] the domain entity with locations, or nil
      def find_with_locations(id)
        orm_record = Todo::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_locations: true)
      end

      # Find a course by ID with enrollments loaded
      # @param id [Integer] the course ID
      # @return [Entity::Course, nil] the domain entity with enrollments, or nil
      def find_with_enrollments(id)
        orm_record = Todo::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_enrollments: true)
      end

      # Find a course by ID with all children loaded
      # @param id [Integer] the course ID
      # @return [Entity::Course, nil] the full aggregate, or nil
      def find_full(id)
        orm_record = Todo::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_events: true, load_locations: true, load_enrollments: true)
      end

      # Find all courses (children not loaded)
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
      # @param load_events [Boolean] whether to load events
      # @param load_locations [Boolean] whether to load locations
      # @param load_enrollments [Boolean] whether to load enrollments
      # @return [Entity::Course] the domain entity
      # rubocop:disable Metrics/ParameterLists
      def rebuild_entity(orm_record, load_events: false, load_locations: false, load_enrollments: false)
        Entity::Course.new(
          id: orm_record.id,
          name: orm_record.name,
          logo: orm_record.logo,
          start_at: orm_record.start_at,
          end_at: orm_record.end_at,
          created_at: orm_record.created_at,
          updated_at: orm_record.updated_at,
          events: load_events ? rebuild_events(orm_record) : nil,
          locations: load_locations ? rebuild_locations(orm_record) : nil,
          enrollments: load_enrollments ? rebuild_enrollments(orm_record) : nil
        )
      end
      # rubocop:enable Metrics/ParameterLists

      def rebuild_events(orm_course)
        Todo::Event
          .where(course_id: orm_course.id)
          .order(:start_at)
          .all
          .map { |e| rebuild_event(e) }
      end

      def rebuild_locations(orm_course)
        Todo::Location
          .where(course_id: orm_course.id)
          .order(:name)
          .all
          .map { |l| rebuild_location(l) }
      end

      def rebuild_event(orm_record)
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

      def rebuild_location(orm_record)
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

      # Rebuild enrollments - aggregates multiple AccountCourse rows per account
      # into a single Enrollment entity with multiple roles
      def rebuild_enrollments(orm_course)
        # Get all account_course_roles for this course
        account_courses = Todo::AccountCourse
                          .where(course_id: orm_course.id)
                          .all

        # Group by account_id
        grouped = account_courses.group_by(&:account_id)

        # Build enrollment for each account
        grouped.map do |account_id, records|
          account = records.first.account
          roles = records.map { |r| r.role.name }.uniq
          first_record = records.min_by(&:id)

          Entity::Enrollment.new(
            id: first_record.id, # Use first record's ID as enrollment ID
            account_id:,
            course_id: orm_course.id,
            account_email: account.email,
            account_name: account.name,
            roles:,
            created_at: nil, # account_course_roles table has no timestamps
            updated_at: nil
          )
        end
      end
    end
  end
end
