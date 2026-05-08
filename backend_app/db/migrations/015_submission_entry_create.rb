# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:submission_entries) do
      primary_key :id
      foreign_key :submission_id, :submissions, null: false, on_delete: :cascade
      foreign_key :requirement_id, :submission_requirements, null: false, on_delete: :cascade
      String :content, null: false
      String :filename
      String :content_type
      Integer :file_size
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
