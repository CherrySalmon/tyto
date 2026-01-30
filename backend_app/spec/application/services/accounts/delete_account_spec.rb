# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Accounts::DeleteAccount do
  let(:account) { Tyto::Account.create(email: 'user@example.com', name: 'User') }
  let(:creator_role) { Tyto::Role.first(name: 'creator') }

  before do
    account.add_role(creator_role)
  end

  describe '#call' do
    it 'returns Success when deleting own account' do
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['creator'])

      result = Tyto::Service::Accounts::DeleteAccount.new.call(requestor:, account_id: account.id)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message).must_equal 'Account deleted'
    end

    it 'returns Success when admin deletes any account' do
      admin = Tyto::Account.create(email: 'admin@example.com', name: 'Admin')
      admin_role = Tyto::Role.first(name: 'admin')
      admin.add_role(admin_role)
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: admin.id, roles: ['admin'])

      result = Tyto::Service::Accounts::DeleteAccount.new.call(requestor:, account_id: account.id)

      _(result).must_be_kind_of Dry::Monads::Result::Success
    end

    it 'returns Failure when deleting other account without admin' do
      other = Tyto::Account.create(email: 'other@example.com', name: 'Other')
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: other.id, roles: ['creator'])

      result = Tyto::Service::Accounts::DeleteAccount.new.call(requestor:, account_id: account.id)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-existent account' do
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: account.id, roles: ['admin'])

      result = Tyto::Service::Accounts::DeleteAccount.new.call(requestor:, account_id: 999_999)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end
  end
end
