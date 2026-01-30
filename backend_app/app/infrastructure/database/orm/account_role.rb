# frozen_string_literal: true

require 'sequel'

module Todo
  class AccountRole < Sequel::Model(:account_roles)
    plugin :validation_helpers
    many_to_one :account
    many_to_one :role
  end
end
