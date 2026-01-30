# frozen_string_literal: true

require_relative '../../types'

module Todo
  module Entity
    # Account entity within the Accounts bounded context.
    # Pure domain object with no infrastructure dependencies.
    # Immutable - updates create new instances via `new()`.
    #
    # Roles follow the same loading convention as Course children:
    #   nil = not loaded (methods requiring them will raise)
    #   []  = loaded but account has no roles
    class Account < Dry::Struct
      # Error raised when accessing roles that weren't loaded
      class RolesNotLoadedError < StandardError; end

      attribute :id, Types::Integer.optional
      attribute :name, Types::String.optional
      attribute :email, Types::Email
      attribute :access_token, Types::String.optional
      attribute :refresh_token, Types::String.optional
      attribute :avatar, Types::String.optional

      # System roles - nil means not loaded (default)
      attribute :roles, Types::Array.of(Types::SystemRole).optional.default(nil)

      # Check if roles are loaded
      def roles_loaded? = !roles.nil?

      # Check if account has a specific role
      # @raise [RolesNotLoadedError] if roles weren't loaded
      def has_role?(role_name)
        require_roles_loaded!
        roles.include?(role_name)
      end

      # Check if account is an admin
      def admin?
        has_role?('admin')
      end

      # Check if account is a creator (can create courses)
      def creator?
        has_role?('creator')
      end

      # Check if account is a member
      def member?
        has_role?('member')
      end

      # Role count
      def role_count
        require_roles_loaded!
        roles.size
      end

      private

      def require_roles_loaded!
        raise RolesNotLoadedError, 'Roles not loaded for this account' if roles.nil?
      end
    end
  end
end
