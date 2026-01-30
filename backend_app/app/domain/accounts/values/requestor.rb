# frozen_string_literal: true

require 'dry-struct'

module Tyto
  module Domain
    module Accounts
      module Values
        # Represents an authenticated identity extracted from a JWT token.
        # Used throughout the application for authorization decisions.
        class Requestor < Dry::Struct
          attribute :account_id, Types::Integer
          attribute :roles, Types::Array.of(Types::Role)

          # System role predicates
          def admin?
            roles.include?('admin')
          end

          def creator?
            roles.include?('creator')
          end

          def member?
            roles.include?('member')
          end

          def has_role?(role_name)
            roles.include?(role_name.to_s)
          end
        end
      end
    end
  end
end
