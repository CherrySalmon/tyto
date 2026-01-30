# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Events::CreateEvent do
  let(:course) { Tyto::Course.create(name: 'Test Course') }
  let(:event_location) { Tyto::Location.create(name: 'Room 101', course_id: course.id) }
  let(:account) { Tyto::Account.create(email: 'test@example.com', name: 'Test User') }
  let(:owner_role) { Tyto::Role.first(name: 'owner') }

  before do
    Tyto::AccountCourse.create(account_id: account.id, course_id: course.id, role_id: owner_role.id)
  end

  let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator']) }

  describe '#call' do
    it 'returns Success with created event' do
      event_data = {
        'name' => 'New Event',
        'location_id' => event_location.id,
        'start_at' => Time.now.iso8601,
        'end_at' => (Time.now + 3600).iso8601
      }

      result = Tyto::Service::Events::CreateEvent.new.call(requestor:, course_id: course.id, event_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.name).must_equal 'New Event'
    end

    it 'returns Failure when name is missing' do
      event_data = { 'location_id' => event_location.id }

      result = Tyto::Service::Events::CreateEvent.new.call(requestor:, course_id: course.id, event_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure when user has no access' do
      other_account = Tyto::Account.create(email: 'other@example.com', name: 'Other')
      other_requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: other_account.id, roles: ['member'])
      event_data = { 'name' => 'New Event', 'location_id' => event_location.id }

      result = Tyto::Service::Events::CreateEvent.new.call(requestor: other_requestor, course_id: course.id, event_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end
  end
end
