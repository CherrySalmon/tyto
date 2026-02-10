# frozen_string_literal: true

require_relative '../../../domain/courses/entities/course'
require_relative '../../../domain/courses/entities/event'
require_relative '../../../domain/courses/entities/location'
require_relative '../../../domain/courses/entities/enrollment'
require_relative '../../../domain/courses/values/course_roles'

module Tyto
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
      # @return [Domain::Courses::Entities::Course, nil] the domain entity or nil if not found
      def find_id(id)
        orm_record = Tyto::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find a course by ID with events loaded
      # @param id [Integer] the course ID
      # @return [Domain::Courses::Entities::Course, nil] the domain entity with events, or nil
      def find_with_events(id)
        orm_record = Tyto::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_events: true)
      end

      # Find a course by ID with locations loaded
      # @param id [Integer] the course ID
      # @return [Domain::Courses::Entities::Course, nil] the domain entity with locations, or nil
      def find_with_locations(id)
        orm_record = Tyto::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_locations: true)
      end

      # Find a course by ID with enrollments loaded
      # @param id [Integer] the course ID
      # @return [Domain::Courses::Entities::Course, nil] the domain entity with enrollments, or nil
      def find_with_enrollments(id)
        orm_record = Tyto::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_enrollments: true)
      end

      # Find a course by ID with all children loaded
      # @param id [Integer] the course ID
      # @return [Domain::Courses::Entities::Course, nil] the full aggregate, or nil
      def find_full(id)
        orm_record = Tyto::Course[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_events: true, load_locations: true, load_enrollments: true)
      end

      # Find multiple courses by IDs (children not loaded)
      # @param ids [Array<Integer>] the course IDs
      # @return [Hash<Integer, Domain::Courses::Entities::Course>] hash of ID => domain entity
      def find_ids(ids)
        return {} if ids.empty?

        Tyto::Course.where(id: ids).all
                    .each_with_object({}) { |record, hash| hash[record.id] = rebuild_entity(record) }
      end

      # Find all courses (children not loaded)
      # @return [Array<Domain::Courses::Entities::Course>] array of domain entities
      def find_all
        Tyto::Course.all.map { |record| rebuild_entity(record) }
      end

      # Find a single enrollment for an account in a course
      # @param account_id [Integer] the account ID
      # @param course_id [Integer] the course ID
      # @return [Domain::Courses::Entities::Enrollment, nil] the enrollment entity or nil if not enrolled
      def find_enrollment(account_id:, course_id:)
        account_courses = Tyto::AccountCourse.where(account_id:, course_id:).all
        return nil if account_courses.empty?

        account = account_courses.first.account
        role_names = account_courses.map { |ac| ac.role.name }.uniq

        Domain::Courses::Entities::Enrollment.new(
          id: account_courses.min_by(&:id).id,
          account_id:,
          course_id:,
          participant: Domain::Courses::Values::Participant.new(
            email: account.email, name: account.name, avatar: account.avatar
          ),
          roles: Domain::Courses::Values::CourseRoles.from(role_names),
          created_at: nil,
          updated_at: nil
        )
      end

      # Create a new course from a domain entity
      # @param entity [Domain::Courses::Entities::Course] the domain entity to persist
      # @return [Domain::Courses::Entities::Course] the persisted entity with ID
      def create(entity)
        orm_record = Tyto::Course.create(
          name: entity.name,
          logo: entity.logo,
          start_at: entity.start_at,
          end_at: entity.end_at
        )

        rebuild_entity(orm_record)
      end

      # Create a new course and assign owner role to the creator
      # @param entity [Domain::Courses::Entities::Course] the domain entity to persist
      # @param owner_account_id [Integer] the account ID of the course creator
      # @return [Domain::Courses::Entities::Course] the persisted entity with ID
      # @raise [RuntimeError] if owner role is not found
      def create_with_owner(entity, owner_account_id:)
        orm_record = Tyto::Course.create(
          name: entity.name,
          logo: entity.logo,
          start_at: entity.start_at,
          end_at: entity.end_at
        )

        owner_role = Tyto::Role.first(name: 'owner')
        raise 'Owner role not found in database' unless owner_role

        Tyto::AccountCourse.create(
          account_id: owner_account_id,
          course_id: orm_record.id,
          role_id: owner_role.id
        )

        rebuild_entity(orm_record)
      end

      # Update an existing course from a domain entity
      # @param entity [Domain::Courses::Entities::Course] the domain entity with updates
      # @return [Domain::Courses::Entities::Course] the updated entity
      def update(entity)
        orm_record = Tyto::Course[entity.id]
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
        orm_record = Tyto::Course[id]
        return false unless orm_record

        orm_record.destroy
        true
      end

      # Set enrollment roles for an account in a course
      # Syncs roles: removes roles not in the list, adds roles in the list
      # @param course_id [Integer] the course ID
      # @param account_id [Integer] the account ID
      # @param roles [Array<String>] the role names to set
      # @return [Domain::Courses::Entities::Enrollment, nil] the updated enrollment or nil if invalid
      def set_enrollment_roles(course_id:, account_id:, roles:)
        return nil if roles.nil? || roles.empty?

        # Get existing AccountCourse records for this account/course
        existing_records = Tyto::AccountCourse.where(account_id:, course_id:).all
        existing_role_names = existing_records.map { |r| r.role.name }

        # Remove roles not in the new list
        roles_to_remove = existing_role_names - roles
        roles_to_remove.each do |role_name|
          role = Tyto::Role.first(name: role_name)
          next unless role

          Tyto::AccountCourse.where(account_id:, course_id:, role_id: role.id).delete
        end

        # Add new roles
        roles_to_add = roles - existing_role_names
        roles_to_add.each do |role_name|
          role = Tyto::Role.first(name: role_name)
          next unless role

          Tyto::AccountCourse.find_or_create(account_id:, course_id:, role_id: role.id)
        end

        # Return the updated enrollment
        find_enrollment(account_id:, course_id:)
      end

      # Add an enrollment for an account in a course with specified roles
      # Creates AccountCourse records for each role
      # @param course_id [Integer] the course ID
      # @param account_id [Integer] the account ID
      # @param roles [Array<String>] the role names to assign
      # @return [Domain::Courses::Entities::Enrollment, nil] the created enrollment or nil if invalid
      def add_enrollment(course_id:, account_id:, roles:)
        return nil if roles.nil? || roles.empty?

        roles.each do |role_name|
          role = Tyto::Role.first(name: role_name)
          next unless role

          Tyto::AccountCourse.find_or_create(account_id:, course_id:, role_id: role.id)
        end

        find_enrollment(account_id:, course_id:)
      end

      private

      # Rebuild a domain entity from an ORM record
      # @param orm_record [Tyto::Course] the Sequel model instance
      # @param load_events [Boolean] whether to load events
      # @param load_locations [Boolean] whether to load locations
      # @param load_enrollments [Boolean] whether to load enrollments
      # @return [Domain::Courses::Entities::Course] the domain entity
      def rebuild_entity(orm_record, load_events: false, load_locations: false, load_enrollments: false)
        Domain::Courses::Entities::Course.new(
          id: orm_record.id,
          name: orm_record.name,
          logo: orm_record.logo,
          start_at: orm_record.start_at,
          end_at: orm_record.end_at,
          created_at: orm_record.created_at,
          updated_at: orm_record.updated_at,
          events: load_events ? Domain::Courses::Values::Events.from(rebuild_events(orm_record)) : nil,
          locations: load_locations ? Domain::Courses::Values::Locations.from(rebuild_locations(orm_record)) : nil,
          enrollments: load_enrollments ? Domain::Courses::Values::Enrollments.from(rebuild_enrollments(orm_record)) : nil
        )
      end

      def rebuild_events(orm_course)
        Tyto::Event
          .where(course_id: orm_course.id)
          .order(:start_at)
          .all
          .map { |e| rebuild_event(e) }
      end

      def rebuild_locations(orm_course)
        Tyto::Location
          .where(course_id: orm_course.id)
          .order(:name)
          .all
          .map { |l| rebuild_location(l) }
      end

      def rebuild_event(orm_record)
        Domain::Courses::Entities::Event.new(
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
        Domain::Courses::Entities::Location.new(
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
        account_courses = Tyto::AccountCourse
                          .where(course_id: orm_course.id)
                          .all

        # Group by account_id
        grouped = account_courses.group_by(&:account_id)

        # Build enrollment for each account
        grouped.map do |account_id, records|
          account = records.first.account
          role_names = records.map { |r| r.role.name }.uniq
          first_record = records.min_by(&:id)

          Domain::Courses::Entities::Enrollment.new(
            id: first_record.id, # Use first record's ID as enrollment ID
            account_id:,
            course_id: orm_course.id,
            participant: Domain::Courses::Values::Participant.new(
              email: account.email, name: account.name, avatar: account.avatar
            ),
            roles: Domain::Courses::Values::CourseRoles.from(role_names),
            created_at: nil, # account_course_roles table has no timestamps
            updated_at: nil
          )
        end
      end
    end
  end
end
