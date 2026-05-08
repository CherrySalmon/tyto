# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:assignments) do
      primary_key :id
      foreign_key :course_id, :courses, null: false, on_delete: :cascade
      foreign_key :event_id, :events, on_delete: :set_null
      String :title, null: false
      Text :description
      String :status, null: false, default: 'draft'
      DateTime :due_at
      TrueClass :allow_late_resubmit, null: false, default: false
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
