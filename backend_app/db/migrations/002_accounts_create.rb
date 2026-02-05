# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:accounts) do
      primary_key :id
      String :name
      String :email, null: false
      String :access_token
      String :refresh_token
      String :avatar
    end
  end
end
