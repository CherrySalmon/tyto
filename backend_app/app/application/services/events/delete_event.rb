# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/events'
require_relative '../application_operation'

module Tyto
  module Service
    module Events
      # Service: Delete an existing event
      # Returns Success(ApiResult) or Failure(ApiResult) with error
      class DeleteEvent < ApplicationOperation
        def initialize(events_repo: Repository::Events.new)
          @events_repo = events_repo
          super()
        end

        def call(requestor:, course_id:, event_id:)
          course_id = step validate_course_id(course_id)
          event_id = step validate_event_id(event_id)
          step verify_course_exists(course_id)
          step find_event(event_id, course_id)
          step authorize(requestor, course_id)
          step delete_event(event_id)

          ok('Event deleted')
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def validate_event_id(event_id)
          id = event_id.to_i
          return Failure(bad_request('Invalid event ID')) if id.zero?

          Success(id)
        end

        def verify_course_exists(course_id)
          course = Course.first(id: course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def find_event(event_id, course_id)
          event = @events_repo.find_id(event_id)
          return Failure(not_found("Event with ID #{event_id} not found")) unless event
          return Failure(bad_request('Event does not belong to this course')) unless event.course_id == course_id

          Success(event)
        end

        def authorize(requestor, course_id)
          course_roles = AccountCourse.where(account_id: requestor.account_id, course_id:).map do |ac|
            ac.role.name
          end
          policy = EventPolicy.new(requestor, course_roles)

          return Failure(forbidden('You have no access to delete events')) unless policy.can_delete?

          Success(true)
        end

        def delete_event(event_id)
          deleted = @events_repo.delete(event_id)
          return Failure(internal_error('Failed to delete event')) unless deleted

          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
