# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:account_roles) do
      foreign_key :role_id, :roles, null: false, on_delete: :cascade
      foreign_key :account_id, :accounts, null: false, on_delete: :cascade
      primary_key %i[role_id account_id]
    end
  end
end
