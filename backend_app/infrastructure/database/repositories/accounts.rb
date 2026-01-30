# frozen_string_literal: true

require_relative '../../../domain/accounts/entities/account'

module Todo
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
        orm_record = Todo::Account[id]
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find an account by ID with roles loaded
      # @param id [Integer] the account ID
      # @return [Entity::Account, nil] the domain entity with roles, or nil
      def find_with_roles(id)
        orm_record = Todo::Account[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_roles: true)
      end

      # Find an account by email (roles not loaded)
      # @param email [String] the email address
      # @return [Entity::Account, nil] the domain entity or nil if not found
      def find_by_email(email)
        orm_record = Todo::Account.first(email: email)
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find an account by email with roles loaded
      # @param email [String] the email address
      # @return [Entity::Account, nil] the domain entity with roles, or nil
      def find_by_email_with_roles(email)
        orm_record = Todo::Account.first(email: email)
        return nil unless orm_record

        rebuild_entity(orm_record, load_roles: true)
      end

      # Find all accounts (roles not loaded)
      # @return [Array<Entity::Account>] array of domain entities
      def find_all
        Todo::Account.all.map { |record| rebuild_entity(record) }
      end

      # Find all accounts with roles loaded
      # @return [Array<Entity::Account>] array of domain entities with roles
      def find_all_with_roles
        Todo::Account.all.map { |record| rebuild_entity(record, load_roles: true) }
      end

      # Create a new account from a domain entity
      # @param entity [Entity::Account] the domain entity to persist
      # @param role_names [Array<String>] optional role names to assign
      # @return [Entity::Account] the persisted entity with ID
      def create(entity, role_names: [])
        orm_record = Todo::Account.create(
          name: entity.name,
          email: entity.email,
          access_token: entity.access_token,
          refresh_token: entity.refresh_token,
          avatar: entity.avatar
        )

        # Assign roles if provided
        role_names.each do |role_name|
          role = Todo::Role.first(name: role_name)
          orm_record.add_role(role) if role
        end

        rebuild_entity(orm_record, load_roles: role_names.any?)
      end

      # Update an existing account from a domain entity
      # @param entity [Entity::Account] the domain entity with updates
      # @param role_names [Array<String>, nil] new role names (nil = don't update roles)
      # @return [Entity::Account] the updated entity
      def update(entity, role_names: nil)
        orm_record = Todo::Account[entity.id]
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
            role = Todo::Role.first(name: role_name)
            orm_record.add_role(role) if role
          end
        end

        rebuild_entity(orm_record.refresh, load_roles: !role_names.nil?)
      end

      # Delete an account by ID
      # @param id [Integer] the account ID
      # @return [Boolean] true if deleted
      def delete(id)
        orm_record = Todo::Account[id]
        return false unless orm_record

        orm_record.destroy
        true
      end

      private

      # Rebuild a domain entity from an ORM record
      # @param orm_record [Todo::Account] the Sequel model instance
      # @param load_roles [Boolean] whether to load roles
      # @return [Entity::Account] the domain entity
      def rebuild_entity(orm_record, load_roles: false)
        Entity::Account.new(
          id: orm_record.id,
          name: orm_record.name,
          email: orm_record.email,
          access_token: orm_record.access_token,
          refresh_token: orm_record.refresh_token,
          avatar: orm_record.avatar,
          roles: load_roles ? rebuild_roles(orm_record) : nil
        )
      end

      def rebuild_roles(orm_account)
        orm_account.roles.map(&:name)
      end
    end
  end
end
