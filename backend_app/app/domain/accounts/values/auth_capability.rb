# frozen_string_literal: true

require 'dry-struct'
require_relative 'system_roles'

module Tyto
  module Domain
    module Accounts
      module Values
        # Security capability extracted from a JWT token.
        # Represents what this request is authorized to do (account_id + roles).
        # Used throughout the application for authorization decisions.
        class AuthCapability < Dry::Struct
          # Coerce arrays to SystemRoles for backward compatibility
          RolesType = Types.Constructor(SystemRoles) do |value|
            case value
            when SystemRoles then value
            when Array then SystemRoles.from(value)
            else value
            end
          end

          attribute :account_id, Types::Integer
          attribute :roles, RolesType

          # Delegate role checking to the SystemRoles value object
          def has_role?(role_name) = roles.has?(role_name)

          # System role predicates - delegate to value object
          def admin? = roles.admin?
          def creator? = roles.creator?
          def member? = roles.member?
        end
      end
    end
  end
end
