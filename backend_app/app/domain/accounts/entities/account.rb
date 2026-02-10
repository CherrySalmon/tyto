# frozen_string_literal: true

require_relative '../../types'
require_relative '../values/system_roles'

module Tyto
  module Domain
    module Accounts
      module Entities
        # Account entity within the Accounts bounded context.
        # Pure domain object with no infrastructure dependencies.
        # Immutable - updates create new instances via `new()`.
        #
        # Roles follow the same loading convention as Course children:
        #   NullSystemRoles = not loaded (queries will raise)
        #   SystemRoles([]) = loaded but account has no roles
        class Account < Dry::Struct
          # Re-export for backward compatibility
          RolesNotLoadedError = Values::NullSystemRoles::NotLoadedError

          # Accepts SystemRoles or NullSystemRoles only - no array coercion
          # Use SystemRoles.from(array) or NullSystemRoles.new explicitly
          RolesType = Types::Any.constructor do |value|
            unless value.is_a?(Values::SystemRoles) ||
                   value.is_a?(Values::NullSystemRoles)
              raise Dry::Struct::Error, "roles must be SystemRoles or NullSystemRoles, got #{value.class}"
            end
            value
          end

          attribute :id, Types::Integer.optional
          attribute :name, Types::String.optional
          attribute :email, Types::Email
          attribute :access_token, Types::String.optional
          attribute :refresh_token, Types::String.optional
          attribute :avatar, Types::String.optional

          # System roles - NullSystemRoles when not loaded
          attribute :roles, RolesType.default { Values::NullSystemRoles.new }

          # Check if roles are loaded
          def roles_loaded?
            roles.respond_to?(:loaded?) ? roles.loaded? : true
          end

          # Delegate role checking to the SystemRoles value object
          def has_role?(role_name) = roles.has?(role_name)

          # Role predicates - delegate to value object
          def admin? = roles.admin?
          def creator? = roles.creator?
          def member? = roles.member?

          # Role count - delegates to value object (raises if not loaded)
          def role_count = roles.count
        end
      end
    end
  end
end
