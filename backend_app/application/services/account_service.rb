# frozen_string_literal: true

require_relative '../policies/account_policy'

module Todo
  # Manages account requests
  class AccountService
    # Custom error classes
    class ForbiddenError < StandardError; end
    class AccountNotFoundError < StandardError; end

    # Lists all accounts, if authorized
    def self.list_all(requestor)
      verify_policy(requestor, :view_all)
      accounts = Account.all.map(&:attributes)
      accounts || raise(ForbiddenError, 'You have no access to list accounts.')
    end

    # Creates a new account, if authorized
    def self.create(requestor, user_data)
      verify_policy(requestor, :create)
      Account.add_account(user_data)
    end

    # Updates an existing account, if authorized
    def self.update(requestor, target_id, user_data)
      verify_policy(requestor, :update, target_id)

      account = Account.first(id: target_id) || raise(AccountNotFoundError, "Account with ID #{target_id} not found.")
      account.update_account(user_data) || raise("Failed to update account with ID #{target_id}.")
    end

    # Removes an account, if authorized
    def self.remove(requestor, target_id)
      verify_policy(requestor, :delete, target_id)

      account = Account.first(id: target_id) || raise(AccountNotFoundError, "Account with ID #{target_id} not found.")
      account.destroy
    end

    private

    # Checks authorization for the requested action
    def self.verify_policy(requestor, action = nil, target_id = nil)
      policy = AccountPolicy.new(requestor, target_id)
      action_check = action ? policy.send("can_#{action}?") : true
      raise(ForbiddenError, 'You have no access to perform this action.') unless action_check

      requestor
    end
  end
end
