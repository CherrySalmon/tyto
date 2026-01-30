# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Domain::Accounts::Values::AuthCapability do
  describe 'attributes' do
    it 'stores account_id and roles' do
      capability = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: 42, roles: ['admin', 'creator'])

      _(capability.account_id).must_equal 42
      _(capability.roles).must_equal ['admin', 'creator']
    end

    it 'requires account_id' do
      _(-> { Tyto::Domain::Accounts::Values::AuthCapability.new(roles: ['admin']) }).must_raise Dry::Struct::Error
    end

    it 'requires roles' do
      _(-> { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: 1) }).must_raise Dry::Struct::Error
    end

    it 'validates roles are valid roles' do
      _(-> { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: 1, roles: ['invalid_role']) }).must_raise Dry::Struct::Error
    end

    it 'accepts system roles' do
      capability = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: 1, roles: ['admin', 'creator', 'member'])
      _(capability.roles).must_equal ['admin', 'creator', 'member']
    end

    it 'accepts course roles' do
      capability = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: 1, roles: ['owner', 'instructor', 'staff', 'student'])
      _(capability.roles).must_equal ['owner', 'instructor', 'staff', 'student']
    end
  end

  describe 'role predicates' do
    it 'returns true for admin?' do
      capability = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: 1, roles: ['admin'])
      _(capability.admin?).must_equal true
      _(capability.creator?).must_equal false
    end

    it 'returns true for creator?' do
      capability = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: 1, roles: ['creator'])
      _(capability.creator?).must_equal true
      _(capability.admin?).must_equal false
    end

    it 'returns true for member?' do
      capability = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: 1, roles: ['member'])
      _(capability.member?).must_equal true
    end

    it 'handles multiple roles' do
      capability = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: 1, roles: ['admin', 'creator'])
      _(capability.admin?).must_equal true
      _(capability.creator?).must_equal true
      _(capability.member?).must_equal false
    end
  end

  describe '#has_role?' do
    it 'checks for specific role' do
      capability = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: 1, roles: ['admin', 'creator'])

      _(capability.has_role?('admin')).must_equal true
      _(capability.has_role?(:admin)).must_equal true
      _(capability.has_role?('member')).must_equal false
    end
  end
end
