# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'logger'
require 'stringio'

describe 'Tyto::Repository::Accounts' do
  let(:repository) { Tyto::Repository::Accounts.new }

  describe '#find_all_with_roles' do
    it 'loads every account and its roles in a constant number of queries' do
      member = Tyto::Role.first(name: 'member')
      5.times do |i|
        account = Tyto::Account.create(email: "many#{i}@example.com")
        account.add_role(member)
      end
      log = StringIO.new
      logger = Logger.new(log)
      Tyto::Api.db.loggers << logger

      begin
        accounts = repository.find_all_with_roles
      ensure
        Tyto::Api.db.loggers.delete(logger)
      end

      _(accounts.size).must_be :>=, 5
      _(accounts.map { |a| a.roles.to_a }).must_include ['member']
      role_queries = log.string.lines.count { |line| line.include?('FROM `roles`') }
      _(role_queries).must_be :<=, 1
    end
  end

  describe 'timestamps' do
    it 'exposes created_at on rebuilt entities' do
      orm = Tyto::Account.create(email: 'stamped@example.com', name: 'Stamped')

      entity = repository.find_id(orm.id)

      _(entity.created_at).must_be_kind_of Time
      _(entity.created_at.to_i).must_equal orm.created_at.to_i
    end
  end

  describe '#find_enrollments' do
    let(:account) { Tyto::Account.create(email: 'enrolled@example.com', name: 'Enrolled') }
    let(:course_a) { Tyto::Course.create(name: 'Course A') }
    let(:course_b) { Tyto::Course.create(name: 'Course B') }

    def enroll(course, role_name)
      role = Tyto::Role.first(name: role_name)
      Tyto::AccountCourse.create(account_id: account.id, course_id: course.id, role_id: role.id)
    end

    it 'returns one membership per course with all course roles, ordered by course name' do
      enroll(course_b, 'student')
      enroll(course_a, 'instructor')
      enroll(course_a, 'staff')

      memberships = repository.find_enrollments(account.id)

      _(memberships.map(&:course_id)).must_equal [course_a.id, course_b.id]
      _(memberships.map(&:course_name)).must_equal ['Course A', 'Course B']
      _(memberships.first.roles.to_a.sort).must_equal %w[instructor staff]
      _(memberships.last.roles.to_a).must_equal ['student']
    end

    it 'returns an empty array for an account with no enrollments' do
      _(repository.find_enrollments(account.id)).must_equal []
    end
  end

  describe '#create' do
    it 'persists a new account and returns entity with ID' do
      entity = Tyto::Domain::Accounts::Entities::Account.new(
        id: nil,
        name: 'John Doe',
        email: 'john@example.com',
        access_token: 'token123',
        refresh_token: 'refresh456',
        avatar: 'https://example.com/avatar.png'
      )

      result = repository.create(entity)

      _(result).must_be_instance_of Tyto::Domain::Accounts::Entities::Account
      _(result.id).wont_be_nil
      _(result.name).must_equal 'John Doe'
      _(result.email).must_equal 'john@example.com'
    end

    it 'persists account with minimal attributes' do
      entity = Tyto::Domain::Accounts::Entities::Account.new(
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
      entity = Tyto::Domain::Accounts::Entities::Account.new(
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
      entity = Tyto::Domain::Accounts::Entities::Account.new(
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
      orm_account = Tyto::Account.create(
        name: 'Test User',
        email: 'test@example.com'
      )

      result = repository.find_id(orm_account.id)

      _(result).must_be_instance_of Tyto::Domain::Accounts::Entities::Account
      _(result.id).must_equal orm_account.id
      _(result.name).must_equal 'Test User'
      _(result.email).must_equal 'test@example.com'
    end

    it 'returns account with roles not loaded' do
      orm_account = Tyto::Account.create(email: 'test@example.com')
      admin_role = Tyto::Role.first(name: 'admin')
      orm_account.add_role(admin_role)

      result = repository.find_id(orm_account.id)

      _(result.roles).must_be_kind_of Tyto::Domain::Accounts::Values::NullSystemRoles
      _(result.roles_loaded?).must_equal false
    end

    it 'returns nil for non-existent account' do
      result = repository.find_id(999_999)

      _(result).must_be_nil
    end
  end

  describe '#find_with_roles' do
    it 'returns account with roles loaded' do
      orm_account = Tyto::Account.create(email: 'test@example.com')
      admin_role = Tyto::Role.first(name: 'admin')
      creator_role = Tyto::Role.first(name: 'creator')
      orm_account.add_role(admin_role)
      orm_account.add_role(creator_role)

      result = repository.find_with_roles(orm_account.id)

      _(result.roles_loaded?).must_equal true
      _(result.roles).must_include 'admin'
      _(result.roles).must_include 'creator'
    end

    it 'returns empty array for account with no roles' do
      orm_account = Tyto::Account.create(email: 'test@example.com')

      result = repository.find_with_roles(orm_account.id)

      _(result.roles_loaded?).must_equal true
      _(result.roles.to_a).must_equal []
    end

    it 'returns nil for non-existent account' do
      _(repository.find_with_roles(999_999)).must_be_nil
    end
  end

  describe '#find_by_email' do
    it 'returns account by email' do
      orm_account = Tyto::Account.create(
        name: 'Email User',
        email: 'findme@example.com'
      )

      result = repository.find_by_email('findme@example.com')

      _(result).must_be_instance_of Tyto::Domain::Accounts::Entities::Account
      _(result.id).must_equal orm_account.id
      _(result.email).must_equal 'findme@example.com'
    end

    it 'returns nil for non-existent email' do
      _(repository.find_by_email('notfound@example.com')).must_be_nil
    end
  end

  describe '#find_by_email_with_roles' do
    it 'returns account with roles by email' do
      orm_account = Tyto::Account.create(email: 'withroles@example.com')
      admin_role = Tyto::Role.first(name: 'admin')
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
      Tyto::Account.create(email: 'one@example.com')
      Tyto::Account.create(email: 'two@example.com')

      result = repository.find_all

      _(result.length).must_equal 2
      result.each { |account| _(account).must_be_instance_of Tyto::Domain::Accounts::Entities::Account }
    end

    it 'returns accounts with roles not loaded' do
      orm_account = Tyto::Account.create(email: 'test@example.com')
      admin_role = Tyto::Role.first(name: 'admin')
      orm_account.add_role(admin_role)

      result = repository.find_all

      result.each { |account| _(account.roles_loaded?).must_equal false }
    end
  end

  describe '#find_all_with_roles' do
    it 'returns all accounts with roles loaded' do
      orm_account = Tyto::Account.create(email: 'test@example.com')
      admin_role = Tyto::Role.first(name: 'admin')
      orm_account.add_role(admin_role)

      result = repository.find_all_with_roles

      result.each { |account| _(account.roles_loaded?).must_equal true }
      _(result.first.roles).must_include 'admin'
    end
  end

  describe '#update' do
    it 'updates existing account and returns updated entity' do
      orm_account = Tyto::Account.create(
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
      orm_account = Tyto::Account.create(email: 'roles@example.com')
      member_role = Tyto::Role.first(name: 'member')
      orm_account.add_role(member_role)

      entity = repository.find_id(orm_account.id)
      result = repository.update(entity, role_names: %w[admin creator])

      _(result.roles_loaded?).must_equal true
      _(result.roles).must_include 'admin'
      _(result.roles).must_include 'creator'
      _(result.roles).wont_include 'member'
    end

    it 'does not update roles when role_names is nil' do
      orm_account = Tyto::Account.create(email: 'keeproles@example.com')
      admin_role = Tyto::Role.first(name: 'admin')
      orm_account.add_role(admin_role)

      entity = repository.find_id(orm_account.id)
      result = repository.update(entity.new(name: 'New Name'), role_names: nil)

      _(result.roles_loaded?).must_equal false

      # Verify roles preserved
      reloaded = repository.find_with_roles(orm_account.id)
      _(reloaded.roles).must_include 'admin'
    end

    it 'raises error for non-existent account' do
      entity = Tyto::Domain::Accounts::Entities::Account.new(
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
      orm_account = Tyto::Account.create(email: 'delete@example.com')

      result = repository.delete(orm_account.id)

      _(result).must_equal true
      _(repository.find_id(orm_account.id)).must_be_nil
    end

    it 'returns false for non-existent account' do
      result = repository.delete(999_999)

      _(result).must_equal false
    end
  end

  describe '#find_or_create_many_by_email' do
    it 'returns existing accounts under found and creates the rest as members, in input order' do
      existing = Tyto::Account.create(email: 'existing@example.com', name: 'Existing User')
      existing.add_role(Tyto::Role.first(name: 'creator'))

      emails = ['new-a@example.com', 'existing@example.com', 'new-b@example.com']
      result = repository.find_or_create_many_by_email(emails)

      _(result.found.map(&:id)).must_equal [existing.id]
      _(result.found.first.roles.to_a).must_equal ['creator']
      _(result.created.map(&:email)).must_equal ['new-a@example.com', 'new-b@example.com']
      _(result.created.map { |a| a.roles.to_a }).must_equal [['member'], ['member']]
      _(Tyto::Account[result.created.first.id].roles.map(&:name)).must_equal ['member']
    end

    it 'does not duplicate accounts across calls' do
      repository.find_or_create_many_by_email(['unique@example.com'])
      second = repository.find_or_create_many_by_email(['unique@example.com'])

      _(second.created).must_equal []
      _(second.found.size).must_equal 1
      _(Tyto::Account.where(email: 'unique@example.com').count).must_equal 1
    end

    it 'retries once when a concurrent request wins the insert, so no duplicate and no failure' do
      original = Tyto::Account.method(:create)
      calls = 0
      losing_first = lambda do |*args, **kwargs|
        calls += 1
        raise Sequel::UniqueConstraintViolation, 'accounts.email is not unique' if calls == 1

        original.call(*args, **kwargs)
      end

      result = Tyto::Account.stub(:create, losing_first) do
        repository.find_or_create_many_by_email(['raced@example.com'])
      end

      _(calls).must_equal 2
      _((result.found + result.created).map(&:email)).must_equal ['raced@example.com']
      _(Tyto::Account.where(email: 'raced@example.com').count).must_equal 1
    end

    it 'creates all or nothing' do
      original = Tyto::Account.method(:create)
      calls = 0
      failing = lambda do |*args, **kwargs|
        calls += 1
        raise Sequel::DatabaseError, 'simulated failure' if calls == 2

        original.call(*args, **kwargs)
      end

      _(proc {
        Tyto::Account.stub(:create, failing) do
          repository.find_or_create_many_by_email(['one@example.com', 'two@example.com'])
        end
      }).must_raise Sequel::DatabaseError
      _(Tyto::Account.first(email: 'one@example.com')).must_be_nil
    end
  end

  describe 'round-trip' do
    it 'maintains data integrity through create -> find -> update -> find cycle' do
      # Create
      original = Tyto::Domain::Accounts::Entities::Account.new(
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
