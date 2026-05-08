# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:submissions) do
      primary_key :id
      foreign_key :assignment_id, :assignments, null: false, on_delete: :cascade
      foreign_key :account_id, :accounts, null: false, on_delete: :cascade
      DateTime :submitted_at, null: false
      DateTime :created_at
      DateTime :updated_at

      unique %i[assignment_id account_id]
    end
  end
end
