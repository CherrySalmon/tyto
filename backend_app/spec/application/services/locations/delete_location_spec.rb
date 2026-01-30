# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Locations::DeleteLocation' do
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

  describe '#call' do
    it 'returns Success when owner deletes location' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)

      requestor = { 'account_id' => account.id }
      result = Tyto::Service::Locations::DeleteLocation.new.call(
        requestor:,
        course_id: course.id,
        location_id: location.id
      )

      _(result.success?).must_equal true
      _(result.value!.message).must_equal 'Location deleted'
    end

    it 'removes location from database' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      location_id = location.id

      requestor = { 'account_id' => account.id }
      Tyto::Service::Locations::DeleteLocation.new.call(
        requestor:,
        course_id: course.id,
        location_id: location_id
      )

      _(Tyto::Location[location_id]).must_be_nil
    end

    it 'returns Failure when location has associated events' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      location = create_test_location(course)
      Tyto::Event.create(
        course_id: course.id,
        location_id: location.id,
        name: 'Test Event',
        start_at: Time.now,
        end_at: Time.now + 3600
      )

      requestor = { 'account_id' => account.id }
      result = Tyto::Service::Locations::DeleteLocation.new.call(
        requestor:,
        course_id: course.id,
        location_id: location.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
      _(result.failure.message).must_include 'associated events'
    end

    it 'returns Failure for student' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      requestor = { 'account_id' => student.id }
      result = Tyto::Service::Locations::DeleteLocation.new.call(
        requestor:,
        course_id: course.id,
        location_id: location.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-existent location' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = { 'account_id' => account.id }
      result = Tyto::Service::Locations::DeleteLocation.new.call(
        requestor:,
        course_id: course.id,
        location_id: 99999
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :not_found
    end

    it 'returns Failure when location does not belong to course' do
      account = create_test_account(roles: ['creator'])
      course1 = create_test_course(account, name: 'Course 1')
      course2 = create_test_course(account, name: 'Course 2')
      location = create_test_location(course1)

      requestor = { 'account_id' => account.id }
      result = Tyto::Service::Locations::DeleteLocation.new.call(
        requestor:,
        course_id: course2.id,
        location_id: location.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end
  end
end
