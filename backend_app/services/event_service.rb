# frozen_string_literal: true

require_relative '../policies/event_policy'

module Todo
  # Manages event requests
  class EventService
    # Custom error classes
    class ForbiddenError < StandardError; end
    class EventNotFoundError < StandardError; end

    # Lists course's event, if authorized
    def self.list(requestor, course_id)
      course = find_course(course_id)
      verify_policy(requestor, :view, course_id)
      events = Event.list_event(course_id)
      events || raise(ForbiddenError, 'You have no access to list events.')
    end

    # Creates a new event, if authorized
    def self.create(requestor, event_data, course_id)
      course = find_course(course_id)

      verify_policy(requestor, :create, course_id)
      Event.add_event(course_id, event_data)
    end

    def self.find(requestor, time)
      Event.find_event(requestor, time)
    end

    def self.update(requestor, event_id, course_id, event_data)
      event = Event.first(id: event_id) || raise(EventNotFoundError, "Event with ID #{event_id} not found")
      verify_policy(requestor, :update, course_id)
      event.update(event_data) || raise("Failed to update event with ID #{event_id}.")
    end

    def self.remove_event(requestor, event_id, course_id)
      event = Event.first(id: event_id)
      verify_policy(requestor, :delete, course_id)
      event.destroy
    end


    def self.find_course(course_id)
      Course.first(id: course_id) || raise(CourseNotFoundError, "Course with ID #{course_id} not found.")
    end

    # Checks authorization for the requested action
    def self.verify_policy(requestor, action = nil, course_id = nil)
      course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id: course_id).map do |role|
        role.role.name
      end
      policy = EventPolicy.new(requestor, course_roles)
      action_check = action ? policy.send("can_#{action}?") : true
      raise(ForbiddenError, 'You have no access to perform this action.') unless action_check

      requestor
    end
  end
end
