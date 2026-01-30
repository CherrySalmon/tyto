# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Events::ListEvents do
  let(:course) { Tyto::Course.create(name: 'Test Course') }
  let(:account) { Tyto::Account.create(email: 'test@example.com', name: 'Test User') }
  let(:owner_role) { Tyto::Role.first(name: 'owner') }

  before do
    Tyto::AccountCourse.create(account_id: account.id, course_id: course.id, role_id: owner_role.id)
  end

  let(:requestor) { Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator']) }

  describe '#call' do
    it 'returns Success with empty list when no events' do
      result = Tyto::Service::Events::ListEvents.new.call(requestor:, course_id: course.id)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message).must_be_empty
    end

    it 'returns Success with events when they exist' do
      location = Tyto::Location.create(name: 'Room 101', course_id: course.id)
      Tyto::Event.create(name: 'Event 1', course_id: course.id, location_id: location.id)
      Tyto::Event.create(name: 'Event 2', course_id: course.id, location_id: location.id)

      result = Tyto::Service::Events::ListEvents.new.call(requestor:, course_id: course.id)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.length).must_equal 2
    end

    it 'returns Failure for invalid course_id' do
      result = Tyto::Service::Events::ListEvents.new.call(requestor:, course_id: 'invalid')

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure for non-existent course' do
      result = Tyto::Service::Events::ListEvents.new.call(requestor:, course_id: 999_999)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end

    it 'returns Failure when user has no access' do
      other_account = Tyto::Account.create(email: 'other@example.com', name: 'Other')
      other_requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: other_account.id, roles: ['member'])

      result = Tyto::Service::Events::ListEvents.new.call(requestor: other_requestor, course_id: course.id)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end
  end
end
