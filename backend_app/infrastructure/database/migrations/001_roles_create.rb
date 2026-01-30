# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    # Create roles table
    create_table(:roles) do
      primary_key :id
      String :name
    end
  end
end
