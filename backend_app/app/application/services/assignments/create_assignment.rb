# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Assignments
      # Service: Create a new assignment for a course
      class CreateAssignment < ApplicationOperation
        def initialize(assignments_repo: Repository::Assignments.new,
                       courses_repo: Repository::Courses.new)
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, assignment_data:)
          step validate_and_load(requestor:, course_id:)
          validated = step validate_input(assignment_data)
          assignment = step persist(validated)

          created(assignment)
        end

        private

        def validate_and_load(requestor:, course_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?
          return Failure(not_found('Course not found')) unless Tyto::Course[@course_id]

          @requestor = requestor
          @enrollment = find_enrollment
          @policy = Policy::Assignment.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to create assignments')) unless @policy.can_create?

          Success(true)
        end

        def find_enrollment
          @courses_repo.find_enrollment(account_id: @requestor.account_id, course_id: @course_id)
        end

        def validate_input(data)
          title = data['title']
          return Failure(bad_request('Assignment title is required')) if title.nil? || title.to_s.strip.empty?

          event_id = data['event_id']&.to_i
          if event_id
            event = Tyto::Event[event_id]
            return Failure(bad_request('Event not found')) unless event
            return Failure(bad_request('Event does not belong to this course')) unless event.course_id == @course_id
          end

          Success(
            course_id: @course_id,
            event_id:,
            title: title.strip,
            description: data['description'],
            due_at: parse_time(data['due_at']),
            allow_late_resubmit: data['allow_late_resubmit'] || false,
            requirements: parse_requirements(data['submission_requirements'])
          )
        end

        def persist(validated)
          requirements = validated.delete(:requirements)

          entity = Domain::Assignments::Entities::Assignment.new(
            id: nil,
            **validated,
            created_at: nil,
            updated_at: nil
          )

          requirement_entities = requirements.map.with_index do |req, idx|
            Domain::Assignments::Entities::SubmissionRequirement.new(
              id: nil,
              assignment_id: 0,
              submission_format: req[:submission_format],
              description: req[:description],
              allowed_types: req[:allowed_types],
              sort_order: req[:sort_order] || idx,
              created_at: nil,
              updated_at: nil
            )
          end

          result = @assignments_repo.create_with_requirements(entity, requirement_entities)
          Success(result)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def parse_requirements(requirements_data)
          return [] unless requirements_data.is_a?(Array)

          requirements_data
            .reject { |req| req['description'].nil? || req['description'].to_s.strip.empty? }
            .map do |req|
              {
                submission_format: req['submission_format'] || 'file',
                description: req['description'],
                allowed_types: sanitize_allowed_types(req['allowed_types']),
                sort_order: req['sort_order']
              }
            end
        end

        def sanitize_allowed_types(value)
          return nil if value.nil? || value.to_s.strip.empty?

          value.to_s.split(',').map { |ext| ext.strip.delete_prefix('.').downcase }.reject(&:empty?).join(',')
        end

        def parse_time(time_value)
          return nil unless time_value

          time_value.is_a?(Time) ? time_value.utc : Time.parse(time_value.to_s).utc
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
