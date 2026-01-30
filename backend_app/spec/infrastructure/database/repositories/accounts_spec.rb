# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Todo::Repository::Accounts' do
  let(:repository) { Todo::Repository::Accounts.new }

  describe '#create' do
    it 'persists a new account and returns entity with ID' do
      entity = Todo::Entity::Account.new(
        id: nil,
        name: 'John Doe',
        email: 'john@example.com',
        access_token: 'token123',
        refresh_token: 'refresh456',
        avatar: 'https://example.com/avatar.png'
      )

      result = repository.create(entity)

      _(result).must_be_instance_of Todo::Entity::Account
      _(result.id).wont_be_nil
      _(result.name).must_equal 'John Doe'
      _(result.email).must_equal 'john@example.com'
    end

    it 'persists account with minimal attributes' do
      entity = Todo::Entity::Account.new(
        id: nil,
        name: nil,
        email: 'minimal@example.com',
        access_token: nil,
        refresh_token: nil,
        avatar: nil
      )

      result = repository.create(entity)

      _(result.id).wont_be_nil
      _(result.email).must_equal 'minimal@example.com'
      _(result.name).must_be_nil
    end

    it 'assigns roles when provided' do
      entity = Todo::Entity::Account.new(
        id: nil,
        name: 'Admin User',
        email: 'admin@example.com',
        access_token: nil,
        refresh_token: nil,
        avatar: nil
      )

      result = repository.create(entity, role_names: %w[admin creator])

      _(result.roles_loaded?).must_equal true
      _(result.roles).must_include 'admin'
      _(result.roles).must_include 'creator'
    end

    it 'returns entity with roles not loaded when no roles provided' do
      entity = Todo::Entity::Account.new(
        id: nil,
        name: 'No Roles',
        email: 'noroles@example.com',
        access_token: nil,
        refresh_token: nil,
        avatar: nil
      )

      result = repository.create(entity)

      _(result.roles_loaded?).must_equal false
    end
  end

  describe '#find_id' do
    it 'returns domain entity for existing account' do
      orm_account = Todo::Account.create(
        name: 'Test User',
        email: 'test@example.com'
      )

      result = repository.find_id(orm_account.id)

      _(result).must_be_instance_of Todo::Entity::Account
      _(result.id).must_equal orm_account.id
      _(result.name).must_equal 'Test User'
      _(result.email).must_equal 'test@example.com'
    end

    it 'returns account with roles not loaded' do
      orm_account = Todo::Account.create(email: 'test@example.com')
      admin_role = Todo::Role.first(name: 'admin')
      orm_account.add_role(admin_role)

      result = repository.find_id(orm_account.id)

      _(result.roles).must_be_nil
      _(result.roles_loaded?).must_equal false
    end

    it 'returns nil for non-existent account' do
      result = repository.find_id(999_999)

      _(result).must_be_nil
    end
  end

  describe '#find_with_roles' do
    it 'returns account with roles loaded' do
      orm_account = Todo::Account.create(email: 'test@example.com')
      admin_role = Todo::Role.first(name: 'admin')
      creator_role = Todo::Role.first(name: 'creator')
      orm_account.add_role(admin_role)
      orm_account.add_role(creator_role)

      result = repository.find_with_roles(orm_account.id)

      _(result.roles_loaded?).must_equal true
      _(result.roles).must_include 'admin'
      _(result.roles).must_include 'creator'
    end

    it 'returns empty array for account with no roles' do
      orm_account = Todo::Account.create(email: 'test@example.com')

      result = repository.find_with_roles(orm_account.id)

      _(result.roles_loaded?).must_equal true
      _(result.roles).must_equal []
    end

    it 'returns nil for non-existent account' do
      _(repository.find_with_roles(999_999)).must_be_nil
    end
  end

  describe '#find_by_email' do
    it 'returns account by email' do
      orm_account = Todo::Account.create(
        name: 'Email User',
        email: 'findme@example.com'
      )

      result = repository.find_by_email('findme@example.com')

      _(result).must_be_instance_of Todo::Entity::Account
      _(result.id).must_equal orm_account.id
      _(result.email).must_equal 'findme@example.com'
    end

    it 'returns nil for non-existent email' do
      _(repository.find_by_email('notfound@example.com')).must_be_nil
    end
  end

  describe '#find_by_email_with_roles' do
    it 'returns account with roles by email' do
      orm_account = Todo::Account.create(email: 'withroles@example.com')
      admin_role = Todo::Role.first(name: 'admin')
      orm_account.add_role(admin_role)

      result = repository.find_by_email_with_roles('withroles@example.com')

      _(result.roles_loaded?).must_equal true
      _(result.roles).must_include 'admin'
    end

    it 'returns nil for non-existent email' do
      _(repository.find_by_email_with_roles('notfound@example.com')).must_be_nil
    end
  end

  describe '#find_all' do
    it 'returns empty array when no accounts exist' do
      result = repository.find_all

      _(result).must_equal []
    end

    it 'returns all accounts as domain entities' do
      Todo::Account.create(email: 'one@example.com')
      Todo::Account.create(email: 'two@example.com')

      result = repository.find_all

      _(result.length).must_equal 2
      result.each { |account| _(account).must_be_instance_of Todo::Entity::Account }
    end

    it 'returns accounts with roles not loaded' do
      orm_account = Todo::Account.create(email: 'test@example.com')
      admin_role = Todo::Role.first(name: 'admin')
      orm_account.add_role(admin_role)

      result = repository.find_all

      result.each { |account| _(account.roles_loaded?).must_equal false }
    end
  end

  describe '#find_all_with_roles' do
    it 'returns all accounts with roles loaded' do
      orm_account = Todo::Account.create(email: 'test@example.com')
      admin_role = Todo::Role.first(name: 'admin')
      orm_account.add_role(admin_role)

      result = repository.find_all_with_roles

      result.each { |account| _(account.roles_loaded?).must_equal true }
      _(result.first.roles).must_include 'admin'
    end
  end

  describe '#update' do
    it 'updates existing account and returns updated entity' do
      orm_account = Todo::Account.create(
        name: 'Original Name',
        email: 'update@example.com'
      )

      entity = repository.find_id(orm_account.id)
      updated_entity = entity.new(name: 'Updated Name')

      result = repository.update(updated_entity)

      _(result.name).must_equal 'Updated Name'
      _(result.id).must_equal orm_account.id

      # Verify persistence
      reloaded = repository.find_id(orm_account.id)
      _(reloaded.name).must_equal 'Updated Name'
    end

    it 'updates roles when role_names provided' do
      orm_account = Todo::Account.create(email: 'roles@example.com')
      member_role = Todo::Role.first(name: 'member')
      orm_account.add_role(member_role)

      entity = repository.find_id(orm_account.id)
      result = repository.update(entity, role_names: %w[admin creator])

      _(result.roles_loaded?).must_equal true
      _(result.roles).must_include 'admin'
      _(result.roles).must_include 'creator'
      _(result.roles).wont_include 'member'
    end

    it 'does not update roles when role_names is nil' do
      orm_account = Todo::Account.create(email: 'keeproles@example.com')
      admin_role = Todo::Role.first(name: 'admin')
      orm_account.add_role(admin_role)

      entity = repository.find_id(orm_account.id)
      result = repository.update(entity.new(name: 'New Name'), role_names: nil)

      _(result.roles_loaded?).must_equal false

      # Verify roles preserved
      reloaded = repository.find_with_roles(orm_account.id)
      _(reloaded.roles).must_include 'admin'
    end

    it 'raises error for non-existent account' do
      entity = Todo::Entity::Account.new(
        id: 999_999,
        name: 'Ghost',
        email: 'ghost@example.com',
        access_token: nil,
        refresh_token: nil,
        avatar: nil
      )

      _ { repository.update(entity) }.must_raise RuntimeError
    end
  end

  describe '#delete' do
    it 'deletes existing account and returns true' do
      orm_account = Todo::Account.create(email: 'delete@example.com')

      result = repository.delete(orm_account.id)

      _(result).must_equal true
      _(repository.find_id(orm_account.id)).must_be_nil
    end

    it 'returns false for non-existent account' do
      result = repository.delete(999_999)

      _(result).must_equal false
    end
  end

  describe 'round-trip' do
    it 'maintains data integrity through create -> find -> update -> find cycle' do
      # Create
      original = Todo::Entity::Account.new(
        id: nil,
        name: 'Full Cycle',
        email: 'cycle@example.com',
        access_token: 'token',
        refresh_token: nil,
        avatar: nil
      )

      created = repository.create(original, role_names: ['member'])
      _(created.id).wont_be_nil

      # Find with roles
      found = repository.find_with_roles(created.id)
      _(found.name).must_equal 'Full Cycle'
      _(found.roles).must_include 'member'

      # Update with new roles
      modified = found.new(name: 'Updated Cycle')
      updated = repository.update(modified, role_names: %w[admin creator])
      _(updated.name).must_equal 'Updated Cycle'
      _(updated.roles).must_include 'admin'

      # Verify final state
      final = repository.find_with_roles(created.id)
      _(final.name).must_equal 'Updated Cycle'
      _(final.roles).must_include 'admin'
      _(final.roles).must_include 'creator'
      _(final.roles).wont_include 'member'
    end
  end
end
