# frozen_string_literal: true

require_relative '../../../domain/accounts/entities/account'
require_relative '../../../domain/accounts/values/system_roles'

module Tyto
  module Repository
    # Repository for Account entities.
    # Maps between ORM records and domain entities.
    #
    # Loading conventions:
    #   find_id / find_all      - Account only (roles = nil)
    #   find_with_roles         - Account + roles loaded
    #   find_by_email           - Account only (roles = nil)
    #   find_by_email_with_roles - Account + roles loaded
    class Accounts
      # Find an account by ID (roles not loaded)
      # @param id [Integer] the account ID
      # @return [Entity::Account, nil] the domain entity or nil if not found
      def find_id(id)
        orm_record = Tyto::Account[id]
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find an account by ID with roles loaded
      # @param id [Integer] the account ID
      # @return [Entity::Account, nil] the domain entity with roles, or nil
      def find_with_roles(id)
        orm_record = Tyto::Account[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_roles: true)
      end

      # Find an account by email (roles not loaded)
      # @param email [String] the email address
      # @return [Entity::Account, nil] the domain entity or nil if not found
      def find_by_email(email)
        orm_record = Tyto::Account.first(email: email)
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find an account by email with roles loaded
      # @param email [String] the email address
      # @return [Entity::Account, nil] the domain entity with roles, or nil
      def find_by_email_with_roles(email)
        orm_record = Tyto::Account.first(email: email)
        return nil unless orm_record

        rebuild_entity(orm_record, load_roles: true)
      end

      # Find all accounts (roles not loaded)
      # @return [Array<Entity::Account>] array of domain entities
      def find_all
        Tyto::Account.all.map { |record| rebuild_entity(record) }
      end

      # Find all accounts with roles loaded
      # @return [Array<Entity::Account>] array of domain entities with roles
      def find_all_with_roles
        Tyto::Account.all.map { |record| rebuild_entity(record, load_roles: true) }
      end

      # Create a new account from a domain entity
      # @param entity [Entity::Account] the domain entity to persist
      # @param role_names [Array<String>] optional role names to assign
      # @return [Entity::Account] the persisted entity with ID
      def create(entity, role_names: [])
        orm_record = Tyto::Account.create(
          name: entity.name,
          email: entity.email,
          access_token: entity.access_token,
          refresh_token: entity.refresh_token,
          avatar: entity.avatar
        )

        # Assign roles if provided
        role_names.each do |role_name|
          role = Tyto::Role.first(name: role_name)
          orm_record.add_role(role) if role
        end

        rebuild_entity(orm_record, load_roles: role_names.any?)
      end

      # Update an existing account from a domain entity
      # @param entity [Entity::Account] the domain entity with updates
      # @param role_names [Array<String>, nil] new role names (nil = don't update roles)
      # @return [Entity::Account] the updated entity
      def update(entity, role_names: nil)
        orm_record = Tyto::Account[entity.id]
        raise "Account not found: #{entity.id}" unless orm_record

        orm_record.update(
          name: entity.name,
          email: entity.email,
          access_token: entity.access_token,
          refresh_token: entity.refresh_token,
          avatar: entity.avatar
        )

        # Update roles if provided
        if role_names
          orm_record.remove_all_roles
          role_names.each do |role_name|
            role = Tyto::Role.first(name: role_name)
            orm_record.add_role(role) if role
          end
        end

        rebuild_entity(orm_record.refresh, load_roles: !role_names.nil?)
      end

      # Delete an account by ID
      # @param id [Integer] the account ID
      # @return [Boolean] true if deleted
      def delete(id)
        orm_record = Tyto::Account[id]
        return false unless orm_record

        orm_record.destroy
        true
      end

      # Find an account by email, or create with 'member' role if not found
      # Domain rule: new accounts always get 'member' role
      # @param email [String] the email address
      # @return [Entity::Account] the found or created account entity
      def find_or_create_by_email(email)
        orm_record = Tyto::Account.first(email: email)

        unless orm_record
          orm_record = Tyto::Account.create(email: email)
          member_role = Tyto::Role.first(name: 'member')
          orm_record.add_role(member_role) if member_role
        end

        rebuild_entity(orm_record)
      end

      private

      # Rebuild a domain entity from an ORM record
      # @param orm_record [Tyto::Account] the Sequel model instance
      # @param load_roles [Boolean] whether to load roles
      # @return [Entity::Account] the domain entity
      def rebuild_entity(orm_record, load_roles: false)
        roles = if load_roles
                  Domain::Accounts::Values::SystemRoles.from(rebuild_role_names(orm_record))
                else
                  Domain::Accounts::Values::NullSystemRoles.new
                end

        Entity::Account.new(
          id: orm_record.id,
          name: orm_record.name,
          email: orm_record.email,
          access_token: orm_record.access_token,
          refresh_token: orm_record.refresh_token,
          avatar: orm_record.avatar,
          roles:
        )
      end

      def rebuild_role_names(orm_account)
        orm_account.roles.map(&:name)
      end
    end
  end
end
