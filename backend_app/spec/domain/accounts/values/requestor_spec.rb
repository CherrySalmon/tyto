# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Domain::Accounts::Values::Requestor do
  describe 'attributes' do
    it 'stores account_id and roles' do
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: 42, roles: ['admin', 'creator'])

      _(requestor.account_id).must_equal 42
      _(requestor.roles).must_equal ['admin', 'creator']
    end

    it 'requires account_id' do
      _(-> { Tyto::Domain::Accounts::Values::Requestor.new(roles: ['admin']) }).must_raise Dry::Struct::Error
    end

    it 'requires roles' do
      _(-> { Tyto::Domain::Accounts::Values::Requestor.new(account_id: 1) }).must_raise Dry::Struct::Error
    end

    it 'validates roles are valid roles' do
      _(-> { Tyto::Domain::Accounts::Values::Requestor.new(account_id: 1, roles: ['invalid_role']) }).must_raise Dry::Struct::Error
    end

    it 'accepts system roles' do
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: 1, roles: ['admin', 'creator', 'member'])
      _(requestor.roles).must_equal ['admin', 'creator', 'member']
    end

    it 'accepts course roles' do
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: 1, roles: ['owner', 'instructor', 'staff', 'student'])
      _(requestor.roles).must_equal ['owner', 'instructor', 'staff', 'student']
    end
  end

  describe 'role predicates' do
    it 'returns true for admin?' do
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: 1, roles: ['admin'])
      _(requestor.admin?).must_equal true
      _(requestor.creator?).must_equal false
    end

    it 'returns true for creator?' do
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: 1, roles: ['creator'])
      _(requestor.creator?).must_equal true
      _(requestor.admin?).must_equal false
    end

    it 'returns true for member?' do
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: 1, roles: ['member'])
      _(requestor.member?).must_equal true
    end

    it 'handles multiple roles' do
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: 1, roles: ['admin', 'creator'])
      _(requestor.admin?).must_equal true
      _(requestor.creator?).must_equal true
      _(requestor.member?).must_equal false
    end
  end

  describe '#has_role?' do
    it 'checks for specific role' do
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: 1, roles: ['admin', 'creator'])

      _(requestor.has_role?('admin')).must_equal true
      _(requestor.has_role?(:admin)).must_equal true
      _(requestor.has_role?('member')).must_equal false
    end
  end
end
