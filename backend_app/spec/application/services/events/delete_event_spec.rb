# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Events::DeleteEvent' do
  include TestHelpers

  def create_test_course(owner_account, name: 'Test Course')
    course = Tyto::Course.create(name: name)
    owner_role = Tyto::Role.find(name: 'owner')
    Tyto::AccountCourse.create(
      course_id: course.id,
      account_id: owner_account.id,
      role_id: owner_role.id
    )
    course
  end

  def create_test_location(course, name: 'Test Location')
    Tyto::Location.create(
      course_id: course.id,
      name: name,
      latitude: 40.7128,
      longitude: -74.0060
    )
  end

  def create_test_event(course, location, name: 'Test Event')
    Tyto::Event.create(
      course_id: course.id,
      location_id: location.id,
      name: name,
      start_at: Time.now + 3600,
      end_at: Time.now + 7200
    )
  end

  describe '#call' do
    it 'returns Success when owner deletes event' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id
      )

      _(result.success?).must_equal true
      api_result = result.value!
      _(api_result.status).must_equal :ok
      _(api_result.http_status_code).must_equal 200
      _(api_result.message).must_equal 'Event deleted'
    end

    it 'removes the event from the database' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)
      event_id = event.id

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event_id
      )

      _(result.success?).must_equal true
      _(Tyto::Event[event_id]).must_be_nil
    end

    it 'allows instructor to delete events' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)

      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      instructor_role = Tyto::Role.find(name: 'instructor')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: instructor.id,
        role_id: instructor_role.id
      )

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: instructor.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id
      )

      _(result.success?).must_equal true
    end

    it 'allows staff to delete events' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)

      staff = create_test_account(name: 'Staff', roles: ['member'])
      staff_role = Tyto::Role.find(name: 'staff')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: staff.id,
        role_id: staff_role.id
      )

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: staff.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id
      )

      _(result.success?).must_equal true
    end

    it 'returns Failure for student (cannot delete events)' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student.id,
        role_id: student_role.id
      )

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
      _(result.failure.http_status_code).must_equal 403
    end

    it 'returns Failure for unauthorized user (no course role)' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)
      other_user = create_test_account(name: 'Other User', roles: ['member'])

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: other_user.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-existent event' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: 99999
      )

      _(result.failure?).must_equal true
      api_result = result.failure
      _(api_result.status).must_equal :not_found
      _(api_result.http_status_code).must_equal 404
    end

    it 'returns Failure for non-existent course' do
      account = create_test_account(roles: ['creator'])

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: 99999,
        event_id: 1
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :not_found
    end

    it 'returns Failure for invalid course_id' do
      account = create_test_account(roles: ['creator'])

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: 'invalid',
        event_id: 1
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure for invalid event_id' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: 'invalid'
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure when event does not belong to specified course' do
      account = create_test_account(roles: ['creator'])
      course1 = create_test_course(account, name: 'Course 1')
      course2 = create_test_course(account, name: 'Course 2')
      location = create_test_location(course1)
      event = create_test_event(course1, location) # Event belongs to course1

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course2.id, # Trying to delete via course2
        event_id: event.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
      _(result.failure.message).must_include 'does not belong'
    end

    it 'does not delete event when authorization fails' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)
      event_id = event.id

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student.id,
        role_id: student_role.id
      )

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event_id
      )

      _(result.failure?).must_equal true
      # Event should still exist
      _(Tyto::Event[event_id]).wont_be_nil
    end
  end

  describe 'API response format' do
    it 'converts success to JSON with message' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id
      )

      api_result = result.value!
      _(api_result.message).must_equal 'Event deleted'
    end

    it 'converts failure to JSON with error format' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::DeleteEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: 99999
      )

      api_result = result.failure
      json = JSON.parse(api_result.to_json)
      _(json['error']).wont_be_nil
      _(json['details']).wont_be_nil
    end
  end
end
