# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Current Event Routes' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Tyto::Api
  end

  # Helper to create a course owned by a given account
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

  # Helper to create a location for testing
  def create_test_location(course, name: 'Test Location')
    Tyto::Location.create(
      course_id: course.id,
      name: name,
      latitude: 40.7128,
      longitude: -74.0060
    )
  end

  # Helper to create an event with specific times
  def create_test_event(course, location, name: 'Test Event', start_at: Time.now, end_at: Time.now + 3600)
    Tyto::Event.create(
      course_id: course.id,
      location_id: location.id,
      name: name,
      start_at: start_at,
      end_at: end_at
    )
  end

  describe 'GET /api/current_event' do
    it 'returns ongoing events' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)

      # Create an ongoing event (started 10 minutes ago, ends in 50 minutes)
      create_test_event(
        course,
        location,
        name: 'Ongoing Event',
        start_at: Time.now - 600,
        end_at: Time.now + 3000
      )

      get '/api/current_event', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_be :>, 0

      event_data = json_response['data'].first
      _(event_data).must_include 'id'
      _(event_data).must_include 'course_id'
      _(event_data).must_include 'location_id'
      _(event_data).must_include 'name'
      _(event_data).must_include 'start_at'
      _(event_data).must_include 'end_at'
      _(event_data).must_include 'course_name'
      _(event_data).must_include 'location_name'
      _(event_data).must_include 'user_attendance_status'
      _(event_data['id']).must_be_kind_of Integer
      _(event_data['name']).must_be_kind_of String
      _(event_data['course_name']).must_equal 'Test Course'
      _(event_data['location_name']).must_equal 'Test Location'
      _(event_data['user_attendance_status']).must_equal false
    end

    it 'excludes past events' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)

      # Create a past event (started 2 hours ago, ended 1 hour ago)
      create_test_event(
        course,
        location,
        name: 'Past Event',
        start_at: Time.now - 7200,
        end_at: Time.now - 3600
      )

      get '/api/current_event', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['data']).must_be_kind_of Array
      # Should not include the past event
      past_events = json_response['data'].select { |e| e['name'] == 'Past Event' }
      _(past_events.length).must_equal 0
    end

    it 'excludes future events' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)

      # Create a future event (starts in 1 hour, ends in 2 hours)
      create_test_event(
        course,
        location,
        name: 'Future Event',
        start_at: Time.now + 3600,
        end_at: Time.now + 7200
      )

      get '/api/current_event', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['data']).must_be_kind_of Array
      # Should not include the future event
      future_events = json_response['data'].select { |e| e['name'] == 'Future Event' }
      _(future_events.length).must_equal 0
    end

    it 'only returns events from enrolled courses' do
      # Create first account with a course and ongoing event
      account1, auth1 = authenticated_header(roles: ['creator'])
      course1 = create_test_course(account1, name: 'Course 1')
      location1 = create_test_location(course1)
      create_test_event(
        course1,
        location1,
        name: 'Event in Course 1',
        start_at: Time.now - 600,
        end_at: Time.now + 3000
      )

      # Create second account with a different course and ongoing event
      account2 = create_test_account(roles: ['creator'])
      course2 = create_test_course(account2, name: 'Course 2')
      location2 = create_test_location(course2)
      create_test_event(
        course2,
        location2,
        name: 'Event in Course 2',
        start_at: Time.now - 600,
        end_at: Time.now + 3000
      )

      # Account1 should only see their own course's event
      get '/api/current_event', nil, auth1

      _(last_response.status).must_equal 200
      _(json_response['data']).must_be_kind_of Array

      event_names = json_response['data'].map { |e| e['name'] }
      _(event_names).must_include 'Event in Course 1'
      _(event_names).wont_include 'Event in Course 2'
    end

    it 'returns empty array when no ongoing events exist' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      get '/api/current_event', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_equal 0
    end

    it 'returns multiple ongoing events from different courses' do
      account, auth = authenticated_header(roles: ['creator'])

      # Create first course with ongoing event
      course1 = create_test_course(account, name: 'Course 1')
      location1 = create_test_location(course1)
      create_test_event(
        course1,
        location1,
        name: 'Event 1',
        start_at: Time.now - 600,
        end_at: Time.now + 3000
      )

      # Create second course with ongoing event
      course2 = create_test_course(account, name: 'Course 2')
      location2 = create_test_location(course2)
      create_test_event(
        course2,
        location2,
        name: 'Event 2',
        start_at: Time.now - 600,
        end_at: Time.now + 3000
      )

      get '/api/current_event', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_equal 2

      event_data = json_response['data'].first
      _(event_data).must_include 'id'
      _(event_data).must_include 'course_id'
      _(event_data).must_include 'name'
      _(event_data).must_include 'start_at'
      _(event_data).must_include 'end_at'
    end

    it 'includes events that just started' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)

      # Create an event that started just now
      create_test_event(
        course,
        location,
        name: 'Just Started Event',
        start_at: Time.now - 5,
        end_at: Time.now + 3600
      )

      get '/api/current_event', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_be :>, 0
    end

    it 'returns user_attendance_status true when attended' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(
        course, location,
        name: 'Attended Event',
        start_at: Time.now - 600,
        end_at: Time.now + 3000
      )
      Tyto::Attendance.create(
        account_id: account.id, course_id: course.id,
        event_id: event.id, name: 'Attended'
      )

      get '/api/current_event', nil, auth

      _(last_response.status).must_equal 200
      event_data = json_response['data'].first
      _(event_data['user_attendance_status']).must_equal true
    end

    it 'returns token error without authentication' do
      get '/api/current_event', nil, {}

      _(last_response.status).must_equal 400
      _(json_response['error']).must_equal 'Token error'
    end
  end
end
