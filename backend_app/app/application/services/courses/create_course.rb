# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Courses
      # Service: Create a new course
      # Returns Success(ApiResult) with created course or Failure(ApiResult) with error
      class CreateCourse < ApplicationOperation
        def initialize(courses_repo: Repository::Courses.new)
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_data:)
          step authorize(requestor)
          validated = step validate_input(course_data)
          course = step persist_course(validated, requestor)

          created(course)
        end

        private

        def authorize(requestor)
          policy = CoursePolicy.new(requestor, nil, [])

          return Failure(forbidden('You have no access to create courses')) unless policy.can_create?

          Success(true)
        end

        def validate_input(course_data)
          name = course_data['name']
          return Failure(bad_request('Course name is required')) if name.nil? || name.to_s.strip.empty?

          Success(
            name: name.strip,
            logo: course_data['logo'],
            start_at: parse_time(course_data['start_at']),
            end_at: parse_time(course_data['end_at'])
          )
        end

        def persist_course(validated, requestor)
          # Create the course using ORM (which handles owner role assignment)
          course = Course.create_course(requestor.account_id, validated)

          # Build response with enrollment info
          result = OpenStruct.new(
            id: course.id,
            name: course.name,
            logo: course.logo,
            start_at: course.start_at,
            end_at: course.end_at,
            created_at: course.created_at,
            updated_at: course.updated_at,
            enroll_identity: ['owner']
          )

          Success(result)
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
