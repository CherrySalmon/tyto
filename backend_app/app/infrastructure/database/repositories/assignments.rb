# frozen_string_literal: true

require_relative '../../../domain/assignments/entities/assignment'
require_relative '../../../domain/assignments/entities/submission_requirement'
require_relative '../../../domain/assignments/values/submission_requirements'

module Tyto
  module Repository
    # Repository for Assignment aggregate root.
    # Maps between ORM records and domain entities.
    #
    # Loading conventions:
    #   find_id                          - Assignment only (requirements = nil)
    #   find_with_requirements           - Assignment + SubmissionRequirements loaded
    #   find_by_course                   - All assignments for course (requirements = nil)
    #   find_by_course_and_status        - Filtered by status (requirements = nil)
    #   find_by_course_with_requirements - All assignments + requirements loaded
    class Assignments
      # Find an assignment by ID (requirements not loaded)
      def find_id(id)
        orm_record = Tyto::Assignment[id]
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find an assignment by ID with requirements loaded
      def find_with_requirements(id)
        orm_record = Tyto::Assignment[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_requirements: true)
      end

      # Find all assignments for a course (requirements not loaded)
      def find_by_course(course_id)
        Tyto::Assignment
          .where(course_id:)
          .order(:created_at)
          .all
          .map { |record| rebuild_entity(record) }
      end

      # Find assignments for a course filtered by status (requirements not loaded)
      def find_by_course_and_status(course_id, status)
        Tyto::Assignment
          .where(course_id:, status:)
          .order(:created_at)
          .all
          .map { |record| rebuild_entity(record) }
      end

      # Find all assignments for a course with requirements loaded
      def find_by_course_with_requirements(course_id)
        Tyto::Assignment
          .where(course_id:)
          .order(:created_at)
          .all
          .map { |record| rebuild_entity(record, load_requirements: true) }
      end

      # Create a new assignment from a domain entity
      def create(entity)
        orm_record = Tyto::Assignment.create(
          course_id: entity.course_id,
          event_id: entity.event_id,
          title: entity.title,
          description: entity.description,
          status: entity.status,
          due_at: entity.due_at&.utc,
          allow_late_resubmit: entity.allow_late_resubmit
        )

        rebuild_entity(orm_record)
      end

      # Create an assignment with its submission requirements
      def create_with_requirements(entity, requirements)
        orm_record = Tyto::Assignment.create(
          course_id: entity.course_id,
          event_id: entity.event_id,
          title: entity.title,
          description: entity.description,
          status: entity.status,
          due_at: entity.due_at&.utc,
          allow_late_resubmit: entity.allow_late_resubmit
        )

        requirements.each do |req|
          Tyto::SubmissionRequirement.create(
            assignment_id: orm_record.id,
            submission_format: req.submission_format,
            description: req.description,
            allowed_types: req.allowed_types,
            sort_order: req.sort_order
          )
        end

        rebuild_entity(orm_record, load_requirements: true)
      end

      # Update an existing assignment from a domain entity
      def update(entity)
        orm_record = Tyto::Assignment[entity.id]
        raise "Assignment not found: #{entity.id}" unless orm_record

        orm_record.update(
          event_id: entity.event_id,
          title: entity.title,
          description: entity.description,
          status: entity.status,
          due_at: entity.due_at&.utc,
          allow_late_resubmit: entity.allow_late_resubmit
        )

        rebuild_entity(orm_record.refresh)
      end

      # Update an assignment and replace its submission requirements
      def update_with_requirements(entity, requirements)
        orm_record = Tyto::Assignment[entity.id]
        raise "Assignment not found: #{entity.id}" unless orm_record

        orm_record.update(
          event_id: entity.event_id,
          title: entity.title,
          description: entity.description,
          status: entity.status,
          due_at: entity.due_at&.utc,
          allow_late_resubmit: entity.allow_late_resubmit
        )

        Tyto::SubmissionRequirement.where(assignment_id: orm_record.id).delete

        requirements.each do |req|
          Tyto::SubmissionRequirement.create(
            assignment_id: orm_record.id,
            submission_format: req.submission_format,
            description: req.description,
            allowed_types: req.allowed_types,
            sort_order: req.sort_order
          )
        end

        rebuild_entity(orm_record.refresh, load_requirements: true)
      end

      # Delete an assignment by ID
      def delete(id)
        orm_record = Tyto::Assignment[id]
        return false unless orm_record

        orm_record.destroy
        true
      end

      private

      def rebuild_entity(orm_record, load_requirements: false)
        Domain::Assignments::Entities::Assignment.new(
          id: orm_record.id,
          course_id: orm_record.course_id,
          event_id: orm_record.event_id,
          title: orm_record.title,
          description: orm_record.description,
          status: orm_record.status,
          due_at: orm_record.due_at,
          allow_late_resubmit: orm_record.allow_late_resubmit,
          created_at: orm_record.created_at,
          updated_at: orm_record.updated_at,
          submission_requirements: load_requirements ? Domain::Assignments::Values::SubmissionRequirements.from(
            rebuild_requirements(orm_record)
          ) : nil
        )
      end

      def rebuild_requirements(orm_assignment)
        Tyto::SubmissionRequirement
          .where(assignment_id: orm_assignment.id)
          .order(:sort_order)
          .all
          .map { |r| rebuild_requirement(r) }
      end

      def rebuild_requirement(orm_record)
        Domain::Assignments::Entities::SubmissionRequirement.new(
          id: orm_record.id,
          assignment_id: orm_record.assignment_id,
          submission_format: orm_record.submission_format,
          description: orm_record.description,
          allowed_types: orm_record.allowed_types,
          sort_order: orm_record.sort_order,
          created_at: orm_record.created_at,
          updated_at: orm_record.updated_at
        )
      end
    end
  end
end
