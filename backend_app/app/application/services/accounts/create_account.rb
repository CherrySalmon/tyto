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
          policy = AccountPolicy.new(requestor, nil)

          return Failure(forbidden('You have no access to create accounts')) unless policy.can_create?

          Success(true)
        end

        def validate_input(account_data)
          email = account_data['email']
          return Failure(bad_request('Email is required')) if email.nil? || email.to_s.strip.empty?

          # Check if email already exists
          existing = Tyto::Account.first(email: email.strip)
          return Failure(bad_request('Email already exists')) if existing

          Success(
            name: account_data['name']&.strip,
            email: email.strip,
            access_token: account_data['access_token'],
            avatar: account_data['avatar'],
            roles: account_data['roles'] || ['member']
          )
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
