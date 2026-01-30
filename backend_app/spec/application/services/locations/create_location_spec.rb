# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Locations::CreateLocation' do
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

  describe '#call' do
    it 'returns Success with created location for owner' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Locations::CreateLocation.new.call(
        requestor:,
        course_id: course.id,
        location_data: { 'name' => 'New Location', 'latitude' => 40.7128, 'longitude' => -74.0060 }
      )

      _(result.success?).must_equal true
      _(result.value!.status).must_equal :created
      _(result.value!.message.name).must_equal 'New Location'
    end

    it 'creates location without coordinates' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Locations::CreateLocation.new.call(
        requestor:,
        course_id: course.id,
        location_data: { 'name' => 'Virtual Location' }
      )

      _(result.success?).must_equal true
      _(result.value!.message.longitude).must_be_nil
      _(result.value!.message.latitude).must_be_nil
    end

    it 'persists location to database' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)
      initial_count = Tyto::Location.count

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      Tyto::Service::Locations::CreateLocation.new.call(
        requestor:,
        course_id: course.id,
        location_data: { 'name' => 'New Location' }
      )

      _(Tyto::Location.count).must_equal(initial_count + 1)
    end

    it 'returns Failure for student (cannot create)' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Locations::CreateLocation.new.call(
        requestor:,
        course_id: course.id,
        location_data: { 'name' => 'Test' }
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure when name is missing' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Locations::CreateLocation.new.call(
        requestor:,
        course_id: course.id,
        location_data: { 'latitude' => 40.7128 }
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure when only longitude provided' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Locations::CreateLocation.new.call(
        requestor:,
        course_id: course.id,
        location_data: { 'name' => 'Test', 'longitude' => -74.0060 }
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure for invalid latitude range' do
      account = create_test_account(roles: ['creator'])
      course = create_test_course(account)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator'])
      result = Tyto::Service::Locations::CreateLocation.new.call(
        requestor:,
        course_id: course.id,
        location_data: { 'name' => 'Test', 'latitude' => 91, 'longitude' => 0 }
      )

      _(result.failure?).must_equal true
      _(result.failure.message).must_include 'Latitude'
    end
  end
end
