# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Assignments
      # Service: Update an existing assignment
      class UpdateAssignment < ApplicationOperation
        def initialize(assignments_repo: Repository::Assignments.new,
                       courses_repo: Repository::Courses.new)
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, assignment_id:, assignment_data:)
          step validate_and_load(requestor:, course_id:, assignment_id:)
          step persist_update(assignment_data)

          ok('Assignment updated')
        end

        private

        def validate_and_load(requestor:, course_id:, assignment_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?

          @requestor = requestor
          @enrollment = find_enrollment
          @policy = AssignmentPolicy.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to update assignments')) unless @policy.can_update?

          load_assignment(assignment_id)
        end

        def load_assignment(assignment_id)
          @assignment = @assignments_repo.find_id(assignment_id.to_i)
          return Failure(not_found('Assignment not found')) unless @assignment
          return Failure(not_found('Assignment not found')) unless @assignment.course_id == @course_id

          Success(true)
        end

        def find_enrollment
          @courses_repo.find_enrollment(account_id: @requestor.account_id, course_id: @course_id)
        end

        def persist_update(data)
          has_requirements = data.key?('submission_requirements')

          if has_requirements && @assignment.status != 'draft'
            return Failure(bad_request('Requirements cannot be updated for published assignments'))
          end

          updated = @assignment.new(
            title: data['title'] ? data['title'].strip : @assignment.title,
            description: data.key?('description') ? data['description'] : @assignment.description,
            due_at: data.key?('due_at') ? parse_time(data['due_at']) : @assignment.due_at,
            event_id: data.key?('event_id') ? data['event_id']&.to_i : @assignment.event_id,
            allow_late_resubmit: data.key?('allow_late_resubmit') ? data['allow_late_resubmit'] : @assignment.allow_late_resubmit
          )

          if has_requirements
            requirement_entities = parse_requirements(data['submission_requirements']).map.with_index do |req, idx|
              Domain::Assignments::Entities::SubmissionRequirement.new(
                id: nil,
                assignment_id: @assignment.id,
                submission_format: req[:submission_format],
                description: req[:description],
                allowed_types: req[:allowed_types],
                sort_order: req[:sort_order] || idx,
                created_at: nil,
                updated_at: nil
              )
            end
            @assignments_repo.update_with_requirements(updated, requirement_entities)
          else
            @assignments_repo.update(updated)
          end

          Success(true)
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
