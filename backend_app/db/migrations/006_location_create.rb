# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    # Create locations table
    create_table(:locations) do
      primary_key :id
      foreign_key :course_id, :courses, on_delete: :cascade

      String :name
      Float :latitude
      Float :longitude
      DateTime :created_at
      DateTime :updated_at

      unique %i[course_id name]
    end
  end
end
