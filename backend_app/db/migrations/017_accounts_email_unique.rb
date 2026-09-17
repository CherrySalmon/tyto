# frozen_string_literal: true

require 'sequel'

# Accounts are found or created by email from two request paths (course
# enrollment and the admin bulk add). The application-level uniqueness check
# cannot stop two concurrent requests from both inserting the same email;
# only the database can. This fails loudly if duplicates already exist, which
# is the right time to find out.
Sequel.migration do
  change do
    alter_table(:accounts) do
      add_index :email, unique: true, name: :accounts_email_unique
    end
  end
end
