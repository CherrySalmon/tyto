# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Todo::Service::Courses::CreateCourse do
  let(:creator_account) { Todo::Account.create(email: 'creator@example.com', name: 'Creator') }
  let(:creator_role) { Todo::Role.first(name: 'creator') }

  before do
    creator_account.add_role(creator_role)
  end

  let(:requestor) { { 'account_id' => creator_account.id, 'roles' => ['creator'] } }

  describe '#call' do
    it 'returns Success with created course' do
      course_data = { 'name' => 'New Course' }

      result = Todo::Service::Courses::CreateCourse.new.call(requestor:, course_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.name).must_equal 'New Course'
      _(result.value!.message.enroll_identity).must_include 'owner'
    end

    it 'returns Failure when name is missing' do
      course_data = {}

      result = Todo::Service::Courses::CreateCourse.new.call(requestor:, course_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure for non-creator' do
      member_account = Todo::Account.create(email: 'member@example.com', name: 'Member')
      member_role = Todo::Role.first(name: 'member')
      member_account.add_role(member_role)
      member_requestor = { 'account_id' => member_account.id, 'roles' => ['member'] }
      course_data = { 'name' => 'Unauthorized Course' }

      result = Todo::Service::Courses::CreateCourse.new.call(requestor: member_requestor, course_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end
  end
end
