# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Locations::ListLocations' do
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
    it 'returns Success with locations for enrolled user' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      create_test_location(course, name: 'Location 1')
      create_test_location(course, name: 'Location 2')

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Locations::ListLocations.new.call(
        requestor:,
        course_id: course.id
      )

      _(result.success?).must_equal true
      api_result = result.value!
      _(api_result.status).must_equal :ok
      _(api_result.message.length).must_equal 2
    end

    it 'returns empty array when no locations exist' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Locations::ListLocations.new.call(
        requestor:,
        course_id: course.id
      )

      _(result.success?).must_equal true
      _(result.value!.message).must_be_empty
    end

    it 'allows student to view locations' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      create_test_location(course)

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Locations::ListLocations.new.call(requestor:, course_id: course.id)

      _(result.success?).must_equal true
    end

    it 'returns Failure for non-enrolled user' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      other_user = create_test_account(name: 'Other', roles: ['member'])

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: other_user.id, roles: ['creator'])
      result = Tyto::Service::Locations::ListLocations.new.call(requestor:, course_id: course.id)

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for invalid course_id' do
      account = create_test_account(roles: ['creator'])
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Locations::ListLocations.new.call(requestor:, course_id: 'invalid')

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure for non-existent course' do
      account = create_test_account(roles: ['creator'])
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Locations::ListLocations.new.call(requestor:, course_id: 99999)

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :not_found
    end
  end

  describe 'Representer integration' do
    it 'serializes locations via LocationsList representer' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      create_test_location(course, name: 'Test Location')

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Locations::ListLocations.new.call(requestor:, course_id: course.id)

      locations = result.value!.message
      json_array = Tyto::Representer::LocationsList.from_entities(locations).to_array

      _(json_array).must_be_kind_of Array
      _(json_array.first['name']).must_equal 'Test Location'
      _(json_array.first['longitude']).must_equal(-74.0060)
    end
  end
end
