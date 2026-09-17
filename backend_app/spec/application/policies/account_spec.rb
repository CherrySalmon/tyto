# frozen_string_literal: true

require_relative '../../spec_helper'

describe Tyto::Policy::Account do
  let(:account) { Tyto::Account.create(email: 'target@example.com', name: 'Target') }
  let(:other) { Tyto::Account.create(email: 'other@example.com', name: 'Other') }

  def capability(account_id, roles)
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id:, roles:)
  end

  describe 'with admin role' do
    let(:requestor) { capability(other.id, ['admin']) }
    let(:policy) { Tyto::Policy::Account.new(requestor, account.id) }

    it 'allows listing all accounts' do
      _(policy.can_view_all?).must_equal true
    end

    it 'allows creating accounts' do
      _(policy.can_create?).must_equal true
    end

    it 'allows changing system roles' do
      _(policy.can_change_system_roles?).must_equal true
    end

    it 'allows viewing a single account and its full details' do
      _(policy.can_view_single?).must_equal true
      _(policy.can_view_details?).must_equal true
    end

    it 'allows updating and deleting any other account' do
      _(policy.can_update?).must_equal true
      _(policy.can_delete?).must_equal true
    end

    it 'denies deleting own account, even as admin' do
      own_policy = Tyto::Policy::Account.new(capability(account.id, ['admin']), account.id)

      _(own_policy.can_delete?).must_equal false
    end
  end

  describe 'with non-admin role acting on own account' do
    let(:requestor) { capability(account.id, ['creator']) }
    let(:policy) { Tyto::Policy::Account.new(requestor, account.id) }

    it 'denies listing all accounts' do
      _(policy.can_view_all?).must_equal false
    end

    it 'denies creating accounts' do
      _(policy.can_create?).must_equal false
    end

    it 'denies changing system roles, even on own account' do
      _(policy.can_change_system_roles?).must_equal false
    end

    it 'allows updating own account' do
      _(policy.can_update?).must_equal true
    end

    it 'allows viewing own account but not the full details (admin panel only)' do
      _(policy.can_view_single?).must_equal true
      _(policy.can_view_details?).must_equal false
    end

    it 'denies deleting own account (attendance history must survive)' do
      _(policy.can_delete?).must_equal false
    end
  end

  describe 'with non-admin role acting on another account' do
    let(:requestor) { capability(other.id, ['creator']) }
    let(:policy) { Tyto::Policy::Account.new(requestor, account.id) }

    it 'denies update, delete, and role changes' do
      _(policy.can_view_single?).must_equal false
      _(policy.can_view_details?).must_equal false
      _(policy.can_update?).must_equal false
      _(policy.can_delete?).must_equal false
      _(policy.can_change_system_roles?).must_equal false
    end
  end

  describe '#summary' do
    let(:requestor) { capability(other.id, ['admin']) }
    let(:policy) { Tyto::Policy::Account.new(requestor, account.id) }

    it 'includes can_create and can_change_system_roles' do
      summary = policy.summary

      _(summary[:can_create]).must_equal true
      _(summary[:can_change_system_roles]).must_equal true
    end
  end
end
