# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Events::FindActiveEvents' do
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

  def create_test_event(course, location, name: 'Test Event', start_at: nil, end_at: nil)
    start_at ||= Time.now - 1800 # 30 minutes ago
    end_at ||= Time.now + 1800   # 30 minutes from now
    Tyto::Event.create(
      course_id: course.id,
      location_id: location.id,
      name: name,
      start_at: start_at,
      end_at: end_at
    )
  end

  describe '#call' do
    it 'returns Success with active events for enrolled user' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location, name: 'Active Event')

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: Time.now
      )

      _(result.success?).must_equal true
      api_result = result.value!
      _(api_result.status).must_equal :ok
      _(api_result.http_status_code).must_equal 200
      _(api_result.message.length).must_equal 1
      _(api_result.message.first.name).must_equal 'Active Event'
    end

    it 'returns empty array when no events are active' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      # Create a past event
      create_test_event(course, location,
                        name: 'Past Event',
                        start_at: Time.now - 7200,
                        end_at: Time.now - 3600)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: Time.now
      )

      _(result.success?).must_equal true
      _(result.value!.message).must_be_empty
    end

    it 'returns empty array when user is not enrolled in any courses' do
      account = create_test_account(roles: ['creator'])
      # Don't create any course enrollments

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: Time.now
      )

      _(result.success?).must_equal true
      _(result.value!.message).must_be_empty
    end

    it 'returns events from all enrolled courses' do
      account = create_test_account(roles: ['creator'])
      course1 = create_test_course(account, name: 'Course 1')
      course2 = create_test_course(account, name: 'Course 2')
      location1 = create_test_location(course1, name: 'Location 1')
      location2 = create_test_location(course2, name: 'Location 2')
      create_test_event(course1, location1, name: 'Event 1')
      create_test_event(course2, location2, name: 'Event 2')

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: Time.now
      )

      _(result.success?).must_equal true
      events = result.value!.message
      _(events.length).must_equal 2
      names = events.map(&:name)
      _(names).must_include 'Event 1'
      _(names).must_include 'Event 2'
    end

    it 'includes location coordinates in events' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      create_test_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: Time.now
      )

      _(result.success?).must_equal true
      event = result.value!.message.first
      _(event.longitude).must_equal(-74.0060)
      _(event.latitude).must_equal 40.7128
    end

    it 'only returns events where time is within start_at and end_at' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)

      # Past event (ended 1 hour ago)
      create_test_event(course, location,
                        name: 'Past Event',
                        start_at: Time.now - 7200,
                        end_at: Time.now - 3600)

      # Current event (started 30 min ago, ends in 30 min)
      create_test_event(course, location,
                        name: 'Current Event',
                        start_at: Time.now - 1800,
                        end_at: Time.now + 1800)

      # Future event (starts in 1 hour)
      create_test_event(course, location,
                        name: 'Future Event',
                        start_at: Time.now + 3600,
                        end_at: Time.now + 7200)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: Time.now
      )

      _(result.success?).must_equal true
      events = result.value!.message
      _(events.length).must_equal 1
      _(events.first.name).must_equal 'Current Event'
    end

    it 'does not return events from courses user is not enrolled in' do
      account = create_test_account(roles: ['creator'])
      other_account = create_test_account(name: 'Other User', roles: ['creator'])
      other_course = create_test_course(other_account, name: 'Other Course')
      location = create_test_location(other_course)
      create_test_event(other_course, location, name: 'Other Event')

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: Time.now
      )

      _(result.success?).must_equal true
      _(result.value!.message).must_be_empty
    end

    it 'allows student to see events from enrolled courses' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      create_test_event(course, location, name: 'Class Event')

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student.id,
        role_id: student_role.id
      )

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: Time.now
      )

      _(result.success?).must_equal true
      _(result.value!.message.first.name).must_equal 'Class Event'
    end

    it 'accepts time as parameter' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)

      future_time = Time.now + 7200 # 2 hours from now
      create_test_event(course, location,
                        name: 'Future Event',
                        start_at: future_time - 1800,
                        end_at: future_time + 1800)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])

      # At current time, no events
      result_now = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: Time.now
      )
      _(result_now.value!.message).must_be_empty

      # At future time, event is active
      result_future = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: future_time
      )
      _(result_future.value!.message.length).must_equal 1
    end

    it 'returns Failure for invalid requestor' do
      result = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor: {},
        time: Time.now
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end
  end

  describe 'Representer integration' do
    it 'serializes active events via EventsList representer' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      create_test_event(course, location, name: 'Active Event')

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::FindActiveEvents.new.call(
        requestor:,
        time: Time.now
      )

      events = result.value!.message
      json_array = Tyto::Representer::EventsList.from_entities(events).to_array

      _(json_array).must_be_kind_of Array
      _(json_array.first['name']).must_equal 'Active Event'
      _(json_array.first['longitude']).must_equal(-74.0060)
    end
  end
end
