# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Accounts::CreateAccount do
  let(:admin_account) { Tyto::Account.create(email: 'admin@example.com', name: 'Admin') }
  let(:admin_role) { Tyto::Role.first(name: 'admin') }

  before do
    admin_account.add_role(admin_role)
  end

  let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: admin_account.id, roles: ['admin']) }

  describe '#call' do
    it 'returns Success with created account' do
      account_data = {
        'name' => 'New User',
        'email' => 'newuser@example.com',
        'roles' => ['member']
      }

      result = Tyto::Service::Accounts::CreateAccount.new.call(requestor:, account_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.email).must_equal 'newuser@example.com'
      _(result.value!.message.roles.to_a).must_equal ['member']
    end

    it 'returns Failure for a non-admin requestor' do
      creator = Tyto::Account.create(email: 'creator@example.com', name: 'Creator')
      creator.add_role(Tyto::Role.first(name: 'creator'))
      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: creator.id, roles: ['creator'])
      account_data = { 'name' => 'New User', 'email' => 'newuser@example.com' }

      result = Tyto::Service::Accounts::CreateAccount.new.call(requestor:, account_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure when a role is not a system role' do
      account_data = { 'name' => 'Bad', 'email' => 'bad@example.com', 'roles' => ['owner'] }

      result = Tyto::Service::Accounts::CreateAccount.new.call(requestor:, account_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure when email is missing' do
      account_data = { 'name' => 'No Email' }

      result = Tyto::Service::Accounts::CreateAccount.new.call(requestor:, account_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure when email already exists' do
      Tyto::Account.create(email: 'existing@example.com', name: 'Existing')
      account_data = { 'name' => 'Duplicate', 'email' => 'existing@example.com' }

      result = Tyto::Service::Accounts::CreateAccount.new.call(requestor:, account_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :conflict
    end
  end
end
