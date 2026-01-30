# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../application_operation'

module Todo
  module Service
    module Accounts
      # Service: List all accounts (admin only)
      # Returns Success(ApiResult) with list of accounts or Failure(ApiResult) with error
      class ListAllAccounts < ApplicationOperation
        def initialize(accounts_repo: Repository::Accounts.new)
          @accounts_repo = accounts_repo
          super()
        end

        def call(requestor:)
          step authorize(requestor)
          accounts = step fetch_accounts

          ok(accounts)
        end

        private

        def authorize(requestor)
          policy = AccountPolicy.new(requestor, nil)

          return Failure(forbidden('You have no access to list accounts')) unless policy.can_view_all?

          Success(true)
        end

        def fetch_accounts
          accounts = @accounts_repo.find_all
          Success(accounts)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
