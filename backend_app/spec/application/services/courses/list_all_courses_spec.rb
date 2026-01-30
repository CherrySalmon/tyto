# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Todo::Service::Courses::ListAllCourses do
  let(:admin_account) { Todo::Account.create(email: 'admin@example.com', name: 'Admin') }
  let(:admin_role) { Todo::Role.first(name: 'admin') }

  before do
    admin_account.add_role(admin_role)
  end

  describe '#call' do
    it 'returns Success with all courses for admin' do
      requestor = { 'account_id' => admin_account.id, 'roles' => ['admin'] }
      Todo::Course.create(name: 'Course 1')
      Todo::Course.create(name: 'Course 2')

      result = Todo::Service::Courses::ListAllCourses.new.call(requestor:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.length).must_equal 2
    end

    it 'returns Failure for non-admin' do
      regular_account = Todo::Account.create(email: 'regular@example.com', name: 'Regular')
      requestor = { 'account_id' => regular_account.id, 'roles' => ['creator'] }

      result = Todo::Service::Courses::ListAllCourses.new.call(requestor:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end
  end
end
