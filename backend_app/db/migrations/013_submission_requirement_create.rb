# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:submission_requirements) do
      primary_key :id
      foreign_key :assignment_id, :assignments, null: false, on_delete: :cascade
      String :submission_format, null: false
      String :description, null: false
      String :allowed_types
      Integer :sort_order, null: false, default: 0
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
