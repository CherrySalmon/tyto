# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Accounts::CreateAccount do
  let(:creator_account) { Tyto::Account.create(email: 'creator@example.com', name: 'Creator') }
  let(:creator_role) { Tyto::Role.first(name: 'creator') }

  before do
    creator_account.add_role(creator_role)
  end

  let(:requestor) { { 'account_id' => creator_account.id, 'roles' => ['creator'] } }

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
      _(result.failure.status).must_equal :bad_request
    end
  end
end
