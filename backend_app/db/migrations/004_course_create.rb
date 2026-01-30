# frozen_string_literal: true

require 'sequel'

Sequel.migration do
    change do
      create_table(:courses) do
        primary_key :id
        foreign_key :role_id, :roles
        foreign_key :account_id, :accounts
        String :name, null: false
        DateTime :created_at
        DateTime :updated_at
        String :logo
        DateTime :start_at
        DateTime :end_at
      end
    end
  end