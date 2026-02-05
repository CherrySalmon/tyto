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
          step persist_update(account, account_data)

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
          policy = AccountPolicy.new(requestor, account_id)

          return Failure(forbidden('You have no access to update this account')) unless policy.can_update?

          Success(true)
        end

        def persist_update(account, account_data)
          # Build updated entity with only provided fields changed
          updated_entity = account.new(
            name: account_data['name']&.strip || account.name,
            email: account_data['email']&.strip || account.email,
            avatar: account_data.key?('avatar') ? account_data['avatar'] : account.avatar
          )

          # Only update roles if explicitly provided
          role_names = account_data['roles']

          @accounts_repo.update(updated_entity, role_names:)
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
