# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../application_operation'

module Tyto
  module Service
    module Accounts
      # Service: The requester's own account with its current system roles.
      # Backs GET /api/auth/session, which the app calls to refresh the roles,
      # name, and avatar it shows, so a role change made while someone is
      # logged in appears without re-login.
      # Returns Success(ApiResult) with the account or Failure(ApiResult)
      class GetOwnAccount < ApplicationOperation
        def initialize(accounts_repo: Repository::Accounts.new)
          @accounts_repo = accounts_repo
          super()
        end

        def call(requestor:)
          step authorize(requestor)
          account = step find_account(requestor.account_id)

          ok(account)
        end

        private

        def authorize(requestor)
          policy = Policy::Account.new(requestor, requestor.account_id)
          return Failure(forbidden('You have no access to this account')) unless policy.can_view_single?

          Success(true)
        end

        def find_account(account_id)
          account = @accounts_repo.find_with_roles(account_id)
          return Failure(not_found('Account not found')) unless account

          Success(account)
        end
      end
    end
  end
end
