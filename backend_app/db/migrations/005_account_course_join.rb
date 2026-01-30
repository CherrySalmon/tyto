# frozen_string_literal: true

require 'sequel'

Sequel.migration do
    change do
      create_table(:account_course_roles) do
        primary_key :id
        foreign_key :account_id, :accounts, on_delete: :cascade
        foreign_key :course_id, :courses, on_delete: :cascade
        foreign_key :role_id, :roles, on_delete: :cascade

        # unique %i[:account_id, :course_id, :role_id]
      end
    end
  end
