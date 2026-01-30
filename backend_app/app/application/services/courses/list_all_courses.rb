# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Courses
      # Service: List all courses (admin only)
      # Returns Success(ApiResult) with list of courses or Failure(ApiResult) with error
      class ListAllCourses < ApplicationOperation
        def initialize(courses_repo: Repository::Courses.new)
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:)
          step authorize(requestor)
          courses = step fetch_courses

          ok(courses)
        end

        private

        def authorize(requestor)
          policy = CoursePolicy.new(requestor, nil, [])

          return Failure(forbidden('You have no access to view all courses')) unless policy.can_view_all?

          Success(true)
        end

        def fetch_courses
          courses = @courses_repo.find_all
          Success(courses)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
