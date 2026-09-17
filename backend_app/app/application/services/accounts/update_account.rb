# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../application_operation'

module Tyto
  module Service
    module Accounts
      # Service: Update an existing account
      # Returns Success(ApiResult) or Failure(ApiResult) with error
      class UpdateAccount < ApplicationOperation
        def initialize(accounts_repo: Repository::Accounts.new)
          @accounts_repo = accounts_repo
          super()
        end

        def call(requestor:, account_id:, account_data:)
          account_id = step validate_account_id(account_id)
          account = step find_account(account_id)
          step authorize(requestor, account_id)
          role_names = step authorize_system_roles(requestor, account_id, account_data['roles'])
          step persist_update(account, account_data, role_names)

          ok('Account updated')
        end

        private

        def validate_account_id(account_id)
          id = account_id.to_i
          return Failure(bad_request('Invalid account ID')) if id.zero?

          Success(id)
        end

        def find_account(account_id)
          account = @accounts_repo.find_id(account_id)
          return Failure(not_found('Account not found')) unless account

          Success(account)
        end

        def authorize(requestor, account_id)
          policy = Policy::Account.new(requestor, account_id)

          return Failure(forbidden('You have no access to update this account')) unless policy.can_update?

          Success(true)
        end

        # Roles are only touched when the request carries them; then only an
        # admin may change them, and every name must be a system role.
        # Returns nil when roles are absent so the repository leaves them alone.
        def authorize_system_roles(requestor, account_id, roles)
          return Success(nil) if roles.nil?

          policy = Policy::Account.new(requestor, account_id)
          return Failure(forbidden('Only admins can change system roles')) unless policy.can_change_system_roles?

          invalid = Array(roles).reject { |role| Types::SystemRole.valid?(role) }
          return Failure(bad_request("Not a system role: #{invalid.join(', ')}")) if invalid.any?

          Success(Array(roles).uniq)
        end

        def persist_update(account, account_data, role_names)
          # Build updated entity with only provided fields changed
          updated_entity = account.new(
            name: account_data['name']&.strip || account.name,
            email: account_data['email']&.strip || account.email,
            avatar: account_data.key?('avatar') ? account_data['avatar'] : account.avatar
          )

          @accounts_repo.update(updated_entity, role_names:)
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
