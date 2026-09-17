# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Accounts::BulkCreateAccounts do
  let(:admin) { Tyto::Account.create(email: 'admin@example.com', name: 'Admin') }
  let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: admin.id, roles: ['admin']) }

  before { admin.add_role(Tyto::Role.first(name: 'admin')) }

  describe '#call' do
    it 'creates every missing email with only the member role and sorts the rest into buckets' do
      Tyto::Account.create(email: 'already@example.com', name: 'Already Here')
      emails = ['one@example.com', 'two@example.com', 'already@example.com', 'nope']

      result = Tyto::Service::Accounts::BulkCreateAccounts.new.call(requestor:, emails:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      outcome = result.value!.message
      _(outcome.created.map(&:email)).must_equal ['one@example.com', 'two@example.com']
      _(outcome.created.map { |a| a.roles.to_a }).must_equal [['member'], ['member']]
      _(outcome.existing.map(&:email)).must_equal ['already@example.com']
      _(outcome.existing.first.roles.to_a).must_equal []
      _(outcome.invalid).must_equal ['nope']
      _(Tyto::Account.first(email: 'one@example.com').roles.map(&:name)).must_equal ['member']
    end

    it 'strips whitespace and de-duplicates emails before creating' do
      emails = [' one@example.com ', 'one@example.com', 'two@example.com']

      result = Tyto::Service::Accounts::BulkCreateAccounts.new.call(requestor:, emails:)

      _(result.value!.message.created.map(&:email)).must_equal ['one@example.com', 'two@example.com']
      _(Tyto::Account.where(email: 'one@example.com').count).must_equal 1
    end

    it 'returns Failure(forbidden) for a non-admin requestor' do
      creator = Tyto::Account.create(email: 'creator@example.com', name: 'Creator')
      creator.add_role(Tyto::Role.first(name: 'creator'))
      non_admin = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: creator.id, roles: ['creator'])

      result = Tyto::Service::Accounts::BulkCreateAccounts.new.call(requestor: non_admin, emails: ['x@example.com'])

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
      _(Tyto::Account.first(email: 'x@example.com')).must_be_nil
    end

    it 'returns Failure(bad_request) for an empty or non-array payload' do
      _(Tyto::Service::Accounts::BulkCreateAccounts.new.call(requestor:, emails: []).failure.status)
        .must_equal :bad_request
      _(Tyto::Service::Accounts::BulkCreateAccounts.new.call(requestor:, emails: 'a@b.c').failure.status)
        .must_equal :bad_request
    end

    it 'creates nothing when any insert fails (single transaction)' do
      original = Tyto::Account.method(:create)
      calls = 0
      failing_create = lambda do |*args, **kwargs|
        calls += 1
        raise Sequel::DatabaseError, 'simulated failure' if calls == 2

        original.call(*args, **kwargs)
      end

      result = Tyto::Account.stub(:create, failing_create) do
        Tyto::Service::Accounts::BulkCreateAccounts.new.call(requestor:, emails: ['one@example.com', 'two@example.com'])
      end

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :internal_error
      _(Tyto::Account.first(email: 'one@example.com')).must_be_nil
      _(Tyto::Account.first(email: 'two@example.com')).must_be_nil
    end
  end
end
