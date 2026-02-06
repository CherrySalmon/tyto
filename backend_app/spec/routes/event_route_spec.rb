# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Event Routes' do
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

  # Helper to create an event
  def create_test_event(course, location, name: 'Test Event', start_at: Time.now, end_at: Time.now + 3600)
    Tyto::Event.create(
      course_id: course.id,
      location_id: location.id,
      name: name,
      start_at: start_at,
      end_at: end_at
    )
  end

  describe 'POST /api/course/:id/event' do
    it 'creates event as instructor' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

      # Enroll as instructor
      instructor_role = Tyto::Role.find(name: 'instructor')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: instructor_account.id,
        role_id: instructor_role.id
      )

      location = create_test_location(course)
      payload = {
        name: 'New Event',
        location_id: location.id,
        start_at: (Time.now + 3600).to_s,
        end_at: (Time.now + 7200).to_s
      }

      post "/api/course/#{course.id}/event", payload.to_json, json_headers(instructor_auth)

      _(last_response.status).must_equal 201
      _(json_response['success']).must_equal true
      _(json_response['message']).must_equal 'Event created'
      _(json_response['event_info']).wont_be_nil
      _(json_response['event_info']['id']).must_be_kind_of Integer
      _(json_response['event_info']['course_id']).must_be_kind_of Integer
      _(json_response['event_info']['location_id']).must_be_kind_of Integer
      _(json_response['event_info']['name']).must_equal 'New Event'
      _(json_response['event_info']).must_include 'start_at'
      _(json_response['event_info']).must_include 'end_at'
    end

    it 'creates event as owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)

      payload = {
        name: 'Owner Event',
        location_id: location.id,
        start_at: (Time.now + 3600).to_s,
        end_at: (Time.now + 7200).to_s
      }

      post "/api/course/#{course.id}/event", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 201
      _(json_response['success']).must_equal true
      _(json_response['event_info']).wont_be_nil
      _(json_response['event_info']['id']).must_be_kind_of Integer
      _(json_response['event_info']['name']).must_equal 'Owner Event'
    end

    it 'returns forbidden as student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      # Enroll as student
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      location = create_test_location(course)
      payload = {
        name: 'Forbidden Event',
        location_id: location.id,
        start_at: (Time.now + 3600).to_s,
        end_at: (Time.now + 7200).to_s
      }

      post "/api/course/#{course.id}/event", payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 403
    end

    it 'returns bad request with invalid JSON' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      post "/api/course/#{course.id}/event", 'invalid json', json_headers(auth)

      _(last_response.status).must_equal 400
      _(json_response['error']).must_equal 'Invalid JSON'
    end
  end

  describe 'GET /api/course/:id/event' do
    it 'lists events for enrolled course' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      create_test_event(course, location, name: 'Event 1')
      create_test_event(course, location, name: 'Event 2')

      get "/api/course/#{course.id}/event", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_equal 2

      event_data = json_response['data'].first
      _(event_data).must_include 'id'
      _(event_data).must_include 'course_id'
      _(event_data).must_include 'location_id'
      _(event_data).must_include 'name'
      _(event_data).must_include 'start_at'
      _(event_data).must_include 'end_at'
    end

    it 'returns empty array when no events exist' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      get "/api/course/#{course.id}/event", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_equal 0
    end

    it 'returns forbidden for non-enrolled users' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      _, other_auth = authenticated_header(roles: ['creator'])

      get "/api/course/#{course.id}/event", nil, other_auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'PUT /api/course/:id/event/:event_id' do
    it 'updates event as owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)

      payload = { name: 'Updated Event Name' }

      put "/api/course/#{course.id}/event/#{event.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['message']).must_equal 'Event updated'
      _(json_response['event_info']).wont_be_nil
      _(json_response['event_info']['id']).must_equal event.id
      _(json_response['event_info']['name']).must_equal 'Updated Event Name'
      _(json_response['event_info']).must_include 'course_id'
      _(json_response['event_info']).must_include 'start_at'
      _(json_response['event_info']).must_include 'end_at'
    end

    it 'updates event as instructor' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

      # Enroll as instructor
      instructor_role = Tyto::Role.find(name: 'instructor')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: instructor_account.id,
        role_id: instructor_role.id
      )

      location = create_test_location(course)
      event = create_test_event(course, location)

      payload = { name: 'Instructor Updated Event' }

      put "/api/course/#{course.id}/event/#{event.id}", payload.to_json, json_headers(instructor_auth)

      _(last_response.status).must_equal 200
    end

    it 'returns forbidden as student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      # Enroll as student
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      location = create_test_location(course)
      event = create_test_event(course, location)

      payload = { name: 'Hacked Event' }

      put "/api/course/#{course.id}/event/#{event.id}", payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 403
    end

    it 'returns not found for invalid event_id' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      payload = { name: 'Nonexistent Event' }

      put "/api/course/#{course.id}/event/99999", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 404
    end
  end

  describe 'DELETE /api/course/:id/event/:event_id' do
    it 'deletes event as owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)

      delete "/api/course/#{course.id}/event/#{event.id}", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['message']).must_equal 'Event deleted'
    end

    it 'deletes event as instructor' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

      # Enroll as instructor
      instructor_role = Tyto::Role.find(name: 'instructor')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: instructor_account.id,
        role_id: instructor_role.id
      )

      location = create_test_location(course)
      event = create_test_event(course, location)

      delete "/api/course/#{course.id}/event/#{event.id}", nil, instructor_auth

      _(last_response.status).must_equal 200
    end

    it 'returns forbidden as student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      # Enroll as student
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      location = create_test_location(course)
      event = create_test_event(course, location)

      delete "/api/course/#{course.id}/event/#{event.id}", nil, student_auth

      _(last_response.status).must_equal 403
    end
  end
end
