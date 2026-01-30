# frozen_string_literal: true

require_relative '../application_operation'

module Tyto
  module Service
    module Courses
      # Service: Update an existing course
      # Returns Success(ApiResult) with updated course or Failure(ApiResult) with error
      class UpdateCourse < ApplicationOperation
        def call(requestor:, course_id:, course_data:)
          course_id = step validate_course_id(course_id)
          course = step find_course(course_id)
          step authorize(requestor, course, course_id)
          step persist_update(course, course_data)

          ok('Course updated')
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def find_course(course_id)
          course = Course.first(id: course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def authorize(requestor, course, course_id)
          course_roles = AccountCourse.where(account_id: requestor.account_id, course_id:).map do |ac|
            ac.role.name
          end
          policy = CoursePolicy.new(requestor, course, course_roles)

          return Failure(forbidden('You have no access to update this course')) unless policy.can_update?

          Success(true)
        end

        def persist_update(course, course_data)
          # Only update provided fields
          update_data = {}
          update_data[:name] = course_data['name'].strip if course_data['name']
          update_data[:logo] = course_data['logo'] if course_data.key?('logo')
          update_data[:start_at] = parse_time(course_data['start_at']) if course_data.key?('start_at')
          update_data[:end_at] = parse_time(course_data['end_at']) if course_data.key?('end_at')

          course.update(update_data)
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
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
