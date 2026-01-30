# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:events) do
      primary_key :id
      foreign_key :course_id, :courses, on_delete: :cascade
      foreign_key :location_id, :locations, on_delete: :cascade

      String :name, null: false
      DateTime :start_at
      DateTime :end_at
      DateTime :created_at
      DateTime :updated_at

      unique %i[start_at end_at]
    end
  end
end
