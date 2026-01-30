# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Accounts::ListAllAccounts do
  let(:admin_account) { Tyto::Account.create(email: 'admin@example.com', name: 'Admin') }
  let(:admin_role) { Tyto::Role.first(name: 'admin') }

  before do
    admin_account.add_role(admin_role)
  end

  describe '#call' do
    it 'returns Success with all accounts for admin' do
      requestor = { 'account_id' => admin_account.id, 'roles' => ['admin'] }
      Tyto::Account.create(email: 'user1@example.com', name: 'User 1')
      Tyto::Account.create(email: 'user2@example.com', name: 'User 2')

      result = Tyto::Service::Accounts::ListAllAccounts.new.call(requestor:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.length).must_be :>=, 3  # admin + 2 users
    end

    it 'returns Failure for non-admin' do
      regular_account = Tyto::Account.create(email: 'regular@example.com', name: 'Regular')
      requestor = { 'account_id' => regular_account.id, 'roles' => ['creator'] }

      result = Tyto::Service::Accounts::ListAllAccounts.new.call(requestor:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end
  end
end
