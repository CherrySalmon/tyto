# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'

module Tyto
  module Domain
    module Accounts
      module Values
        # Value object representing a collection of system-level roles.
        # Encapsulates role checking logic for Account and AuthCapability.
        # Note: Uses Types::Role (all roles) to support AuthCapability which
        # may receive any role type in JWT tokens.
        class SystemRoles < Dry::Struct
          attribute :roles, Types::Array.of(Types::Role)

          # Check if collection contains a specific role
          # @param role [String, Symbol] the role to check
          # @return [Boolean]
          def has?(role)
            roles.include?(role.to_s)
          end

          # Alias for backward compatibility with tests
          alias include? has?

          # Role predicates
          def admin? = has?('admin')
          def creator? = has?('creator')
          def member? = has?('member')

          # Collection queries
          def any? = roles.any?
          def empty? = roles.empty?
          def count = roles.size
          def to_a = roles.dup

          # For interface compatibility with NullSystemRoles
          def loaded? = true

          # Convenience constructor from array
          def self.from(role_array)
            new(roles: role_array || [])
          end
        end

        # Null object for when roles are not loaded.
        # All methods raise NotLoadedError to enforce explicit loading.
        class NullSystemRoles
          def has?(_role)
            raise NotLoadedError, 'Roles not loaded for this account'
          end

          alias include? has?

          def admin? = has?('admin')
          def creator? = has?('creator')
          def member? = has?('member')

          def any?
            raise NotLoadedError, 'Roles not loaded for this account'
          end

          def empty?
            raise NotLoadedError, 'Roles not loaded for this account'
          end

          def count
            raise NotLoadedError, 'Roles not loaded for this account'
          end

          def to_a
            raise NotLoadedError, 'Roles not loaded for this account'
          end

          def loaded? = false

          # Error raised when accessing roles that weren't loaded
          class NotLoadedError < StandardError; end
        end
      end
    end
  end
end
