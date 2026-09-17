# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../application_operation'

module Tyto
  module Service
    module Accounts
      # Service: Create a new account
      # Returns Success(ApiResult) with created account or Failure(ApiResult) with error
      class CreateAccount < ApplicationOperation
        def initialize(accounts_repo: Repository::Accounts.new)
          @accounts_repo = accounts_repo
          super()
        end

        def call(requestor:, account_data:)
          step authorize(requestor)
          validated = step validate_input(account_data)
          account = step persist_account(validated)

          created(account)
        end

        private

        def authorize(requestor)
          policy = Policy::Account.new(requestor, nil)

          return Failure(forbidden('You have no access to create accounts')) unless policy.can_create?

          Success(true)
        end

        def validate_input(account_data)
          email = step validate_email(account_data['email'])
          roles = step validate_roles(account_data['roles'])

          return Failure(conflict('Email already exists')) if @accounts_repo.find_by_email(email)

          Success(
            name: account_data['name']&.strip,
            email:,
            access_token: account_data['access_token'],
            avatar: account_data['avatar'],
            roles:
          )
        end

        def validate_email(email)
          email = email.to_s.strip
          return Failure(bad_request('Email is required')) if email.empty?
          return Failure(bad_request('Email is not valid')) unless Types::Email.valid?(email)

          Success(email)
        end

        # New accounts default to 'member'; any given roles must be system roles
        def validate_roles(roles)
          return Success(['member']) if roles.nil? || roles.empty?

          invalid = Array(roles).reject { |role| Types::SystemRole.valid?(role) }
          return Failure(bad_request("Not a system role: #{invalid.join(', ')}")) if invalid.any?

          Success(Array(roles).uniq)
        end

        def persist_account(validated)
          # Create domain entity (without ID)
          # Use NullSystemRoles because roles are assigned by repository during persistence
          entity = Domain::Accounts::Entities::Account.new(
            id: nil,
            name: validated[:name],
            email: validated[:email],
            access_token: validated[:access_token],
            refresh_token: nil,
            avatar: validated[:avatar],
            roles: Domain::Accounts::Values::NullSystemRoles.new
          )

          # Persist and return with roles loaded
          account = @accounts_repo.create(entity, role_names: validated[:roles])
          Success(account)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
