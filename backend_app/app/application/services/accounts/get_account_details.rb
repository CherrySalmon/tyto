# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../../responses/account_details'
require_relative '../application_operation'

module Tyto
  module Service
    module Accounts
      # Service: Fetch one account with its system roles and course memberships
      # for the admin panel's detail view. Admin only.
      # Returns Success(ApiResult) with Response::AccountDetails or Failure(ApiResult)
      class GetAccountDetails < ApplicationOperation
        def initialize(accounts_repo: Repository::Accounts.new)
          @accounts_repo = accounts_repo
          super()
        end

        def call(requestor:, account_id:)
          account_id = step validate_account_id(account_id)
          step authorize(requestor, account_id)
          account = step find_account(account_id)
          enrollments = step find_enrollments(account_id)

          ok(Response::AccountDetails.new(account:, enrollments:))
        end

        private

        def validate_account_id(account_id)
          id = account_id.to_i
          return Failure(bad_request('Invalid account ID')) if id.zero?

          Success(id)
        end

        def authorize(requestor, account_id)
          policy = Policy::Account.new(requestor, account_id)
          return Failure(forbidden('You have no access to view this account')) unless policy.can_view_details?

          Success(true)
        end

        def find_account(account_id)
          account = @accounts_repo.find_with_roles(account_id)
          return Failure(not_found('Account not found')) unless account

          Success(account)
        end

        def find_enrollments(account_id)
          Success(@accounts_repo.find_enrollments(account_id))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
