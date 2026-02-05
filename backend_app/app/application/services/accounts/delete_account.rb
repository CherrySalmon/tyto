# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../application_operation'

module Tyto
  module Service
    module Accounts
      # Service: Delete an account
      # Returns Success(ApiResult) or Failure(ApiResult) with error
      class DeleteAccount < ApplicationOperation
        def initialize(accounts_repo: Repository::Accounts.new)
          @accounts_repo = accounts_repo
          super()
        end

        def call(requestor:, account_id:)
          account_id = step validate_account_id(account_id)
          step find_account(account_id)
          step authorize(requestor, account_id)
          step delete_account(account_id)

          ok('Account deleted')
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

          return Failure(forbidden('You have no access to delete this account')) unless policy.can_delete?

          Success(true)
        end

        def delete_account(account_id)
          @accounts_repo.delete(account_id)
          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
