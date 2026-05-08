# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/submissions'
require_relative '../../../infrastructure/database/repositories/assignments'
require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../responses/policy_wrapper'
require_relative '../application_operation'

module Tyto
  module Service
    module Submissions
      # Service: List submissions for an assignment.
      # Teaching staff see all; students see only their own.
      class ListSubmissions < ApplicationOperation
        def initialize(submissions_repo: Repository::Submissions.new,
                       assignments_repo: Repository::Assignments.new,
                       courses_repo: Repository::Courses.new)
          @submissions_repo = submissions_repo
          @assignments_repo = assignments_repo
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:, assignment_id:)
          step validate_and_load(requestor:, course_id:, assignment_id:)
          submissions = step fetch_submissions

          ok(submissions)
        end

        private

        def validate_and_load(requestor:, course_id:, assignment_id:)
          @course_id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if @course_id.zero?

          @requestor = requestor
          @enrollment = find_enrollment
          @policy = Policy::Submission.new(@requestor, @enrollment)
          return Failure(forbidden('You are not authorized to view submissions')) unless @policy.can_view_own?

          load_assignment(assignment_id)
        end

        def load_assignment(assignment_id)
          @assignment = @assignments_repo.find_id(assignment_id.to_i)
          return Failure(not_found('Assignment not found')) unless @assignment
          return Failure(not_found('Assignment not found')) unless @assignment.course_id == @course_id

          Success(true)
        end

        def fetch_submissions
          submissions = if @policy.can_view_all?
                          @submissions_repo.find_by_assignment_full(@assignment.id)
                        else
                          sub = @submissions_repo.find_by_account_assignment_full(
                            @requestor.account_id, @assignment.id
                          )
                          sub ? [sub] : []
                        end

          wrapped = submissions.map { |s| Response::PolicyWrapper.new(s, policies: @policy.summary) }
          Success(wrapped)
        end

        def find_enrollment
          @courses_repo.find_enrollment(account_id: @requestor.account_id, course_id: @course_id)
        end
      end
    end
  end
end
