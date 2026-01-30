# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Events::UpdateEvent' do
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
    it 'returns Success with updated event for authorized user' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'name' => 'Updated Event Name' }
      )

      _(result.success?).must_equal true
      api_result = result.value!
      _(api_result.status).must_equal :ok
      _(api_result.http_status_code).must_equal 200
      _(api_result.message.name).must_equal 'Updated Event Name'
    end

    it 'allows partial updates - only updates provided fields' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location, name: 'Original Name')
      original_start = event.start_at

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'name' => 'New Name' } # Only updating name
      )

      _(result.success?).must_equal true
      updated_event = result.value!.message
      _(updated_event.name).must_equal 'New Name'
      # start_at should remain unchanged (within 1 second tolerance for DB precision)
      _(updated_event.start_at.to_i).must_be_close_to(original_start.to_i, 1)
    end

    it 'updates all fields when all are provided' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location1 = create_test_location(course, name: 'Location 1')
      location2 = create_test_location(course, name: 'Location 2')
      event = create_test_event(course, location1)

      new_start = (Time.now + 10_800).iso8601
      new_end = (Time.now + 14_400).iso8601

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: {
          'name' => 'Fully Updated Event',
          'location_id' => location2.id,
          'start_at' => new_start,
          'end_at' => new_end
        }
      )

      _(result.success?).must_equal true
      updated = result.value!.message
      _(updated.name).must_equal 'Fully Updated Event'
      _(updated.location_id).must_equal location2.id
    end

    it 'includes location coordinates in updated event' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'name' => 'Updated' }
      )

      _(result.success?).must_equal true
      updated_event = result.value!.message
      _(updated_event.longitude).must_equal(-74.0060)
      _(updated_event.latitude).must_equal 40.7128
    end

    it 'persists the update to the database' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location, name: 'Original')

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'name' => 'Persisted Update' }
      )

      _(result.success?).must_equal true
      # Reload from database
      reloaded = Tyto::Event[event.id]
      _(reloaded.name).must_equal 'Persisted Update'
    end

    it 'returns Failure for unauthorized user (no course role)' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)
      other_user = create_test_account(name: 'Other User', roles: ['member'])

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: other_user.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'name' => 'Hacked Name' }
      )

      _(result.failure?).must_equal true
      api_result = result.failure
      _(api_result.status).must_equal :forbidden
      _(api_result.http_status_code).must_equal 403
    end

    it 'returns Failure for student (cannot update events)' do
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

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'name' => 'Student Update' }
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'allows instructor to update events' do
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

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: instructor.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'name' => 'Instructor Update' }
      )

      _(result.success?).must_equal true
      _(result.value!.message.name).must_equal 'Instructor Update'
    end

    it 'allows staff to update events' do
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

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: staff.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'name' => 'Staff Update' }
      )

      _(result.success?).must_equal true
      _(result.value!.message.name).must_equal 'Staff Update'
    end

    it 'returns Failure for non-existent event' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: 99999,
        event_data: { 'name' => 'Test' }
      )

      _(result.failure?).must_equal true
      api_result = result.failure
      _(api_result.status).must_equal :not_found
      _(api_result.http_status_code).must_equal 404
    end

    it 'returns Failure for non-existent course' do
      account = create_test_account(roles: ['creator'])

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: 99999,
        event_id: 1,
        event_data: { 'name' => 'Test' }
      )

      _(result.failure?).must_equal true
      api_result = result.failure
      _(api_result.status).must_equal :not_found
    end

    it 'returns Failure for invalid course_id' do
      account = create_test_account(roles: ['creator'])

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: 'invalid',
        event_id: 1,
        event_data: { 'name' => 'Test' }
      )

      _(result.failure?).must_equal true
      api_result = result.failure
      _(api_result.status).must_equal :bad_request
    end

    it 'returns Failure for invalid event_id' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: 'invalid',
        event_data: { 'name' => 'Test' }
      )

      _(result.failure?).must_equal true
      api_result = result.failure
      _(api_result.status).must_equal :bad_request
    end

    it 'returns Failure when event does not belong to specified course' do
      account = create_test_account(roles: ['creator'])
      course1 = create_test_course(account, name: 'Course 1')
      course2 = create_test_course(account, name: 'Course 2')
      location = create_test_location(course1)
      event = create_test_event(course1, location) # Event belongs to course1

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course2.id, # Trying to update via course2
        event_id: event.id,
        event_data: { 'name' => 'Test' }
      )

      _(result.failure?).must_equal true
      api_result = result.failure
      _(api_result.status).must_equal :bad_request
      _(api_result.message).must_include 'does not belong'
    end

    it 'returns Failure when name is set to empty string' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'name' => '' }
      )

      _(result.failure?).must_equal true
      api_result = result.failure
      _(api_result.status).must_equal :bad_request
      _(api_result.message).must_include 'name'
    end

    it 'returns Failure when end_at is before start_at' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: {
          'start_at' => (Time.now + 7200).iso8601,
          'end_at' => (Time.now + 3600).iso8601
        }
      )

      _(result.failure?).must_equal true
      api_result = result.failure
      _(api_result.status).must_equal :bad_request
      _(api_result.message).must_include 'End time must be after start time'
    end

    it 'validates end_at against existing start_at when only end_at is updated' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      # Create event with start_at = now + 1hr, end_at = now + 2hr
      event = create_test_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      # Try to set end_at to before the existing start_at
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'end_at' => (Time.now + 1800).iso8601 } # 30 min from now, before start_at
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure for invalid time format' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'start_at' => 'not-a-valid-time' }
      )

      _(result.failure?).must_equal true
      api_result = result.failure
      _(api_result.status).must_equal :bad_request
      _(api_result.message).must_include 'time'
    end
  end

  describe 'Representer integration' do
    it 'serializes updated event via Event representer' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      event = create_test_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: event.id,
        event_data: { 'name' => 'Serialized Update' }
      )

      event_result = result.value!.message
      json_hash = Tyto::Representer::Event.new(event_result).to_hash

      _(json_hash).must_be_kind_of Hash
      _(json_hash['name']).must_equal 'Serialized Update'
      _(json_hash['longitude']).must_equal(-74.0060)
      _(json_hash['start_at']).must_be_kind_of String # ISO8601 format
    end

    it 'converts failure to JSON with error format' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Events::UpdateEvent.new.call(
        requestor:,
        course_id: course.id,
        event_id: 99999,
        event_data: { 'name' => 'Test' }
      )

      api_result = result.failure
      json = JSON.parse(api_result.to_json)
      _(json['error']).wont_be_nil
      _(json['details']).wont_be_nil
    end
  end
end
