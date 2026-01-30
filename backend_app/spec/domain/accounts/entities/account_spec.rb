# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Entity::Account' do
  let(:valid_attributes) do
    {
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      access_token: 'token123',
      refresh_token: 'refresh456',
      avatar: 'https://example.com/avatar.png'
    }
  end

  describe 'creation' do
    it 'creates a valid account' do
      account = Tyto::Entity::Account.new(valid_attributes)

      _(account.id).must_equal 1
      _(account.name).must_equal 'John Doe'
      _(account.email).must_equal 'john@example.com'
      _(account.access_token).must_equal 'token123'
      _(account.avatar).must_equal 'https://example.com/avatar.png'
    end

    it 'creates an account with minimal attributes' do
      account = Tyto::Entity::Account.new(
        id: nil,
        name: nil,
        email: 'minimal@example.com',
        access_token: nil,
        refresh_token: nil,
        avatar: nil
      )

      _(account.email).must_equal 'minimal@example.com'
      _(account.name).must_be_nil
    end

    it 'rejects invalid email format' do
      _ { Tyto::Entity::Account.new(valid_attributes.merge(email: 'invalid-email')) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects empty email' do
      _ { Tyto::Entity::Account.new(valid_attributes.merge(email: '')) }
        .must_raise Dry::Struct::Error
    end
  end

  describe 'immutability' do
    it 'allows valid updates via new()' do
      account = Tyto::Entity::Account.new(valid_attributes)
      updated = account.new(name: 'Jane Doe')

      _(updated.name).must_equal 'Jane Doe'
      _(updated.email).must_equal account.email # Preserved
    end

    it 'enforces email constraint on updates' do
      account = Tyto::Entity::Account.new(valid_attributes)

      _ { account.new(email: 'invalid') }.must_raise Dry::Struct::Error
    end
  end

  describe 'roles' do
    describe 'default state (not loaded)' do
      it 'has nil roles by default' do
        account = Tyto::Entity::Account.new(valid_attributes)

        _(account.roles).must_be_nil
        _(account.roles_loaded?).must_equal false
      end
    end

    describe 'loaded state' do
      it 'can have roles loaded (empty)' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: []))

        _(account.roles).must_equal []
        _(account.roles_loaded?).must_equal true
      end

      it 'can have roles loaded (with data)' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: %w[admin creator]))

        _(account.roles).must_equal %w[admin creator]
        _(account.roles_loaded?).must_equal true
      end

      it 'rejects invalid role names' do
        _ { Tyto::Entity::Account.new(valid_attributes.merge(roles: ['invalid_role'])) }
          .must_raise Dry::Struct::Error
      end
    end

    describe '#has_role?' do
      it 'returns true when account has the role' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: %w[admin creator]))

        _(account.has_role?('admin')).must_equal true
        _(account.has_role?('creator')).must_equal true
      end

      it 'returns false when account lacks the role' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: ['member']))

        _(account.has_role?('admin')).must_equal false
      end

      it 'raises RolesNotLoadedError when roles not loaded' do
        account = Tyto::Entity::Account.new(valid_attributes)

        _ { account.has_role?('admin') }
          .must_raise Tyto::Entity::Account::RolesNotLoadedError
      end
    end

    describe '#admin?' do
      it 'returns true for admin accounts' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: ['admin']))

        _(account.admin?).must_equal true
      end

      it 'returns false for non-admin accounts' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: ['member']))

        _(account.admin?).must_equal false
      end
    end

    describe '#creator?' do
      it 'returns true for creator accounts' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: ['creator']))

        _(account.creator?).must_equal true
      end

      it 'returns false for non-creator accounts' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: ['member']))

        _(account.creator?).must_equal false
      end
    end

    describe '#member?' do
      it 'returns true for member accounts' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: ['member']))

        _(account.member?).must_equal true
      end

      it 'returns false for non-member accounts' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: ['admin']))

        _(account.member?).must_equal false
      end
    end

    describe '#role_count' do
      it 'returns count when roles are loaded' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: %w[admin creator]))

        _(account.role_count).must_equal 2
      end

      it 'returns 0 for empty roles' do
        account = Tyto::Entity::Account.new(valid_attributes.merge(roles: []))

        _(account.role_count).must_equal 0
      end

      it 'raises RolesNotLoadedError when roles not loaded' do
        account = Tyto::Entity::Account.new(valid_attributes)

        _ { account.role_count }
          .must_raise Tyto::Entity::Account::RolesNotLoadedError
      end
    end
  end
end
