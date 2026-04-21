# frozen_string_literal: true

require 'sequel'

# Drop the table-level `unique (start_at, end_at)` constraint on events.
# Multiple legitimate events can share the same time window (e.g. parallel
# workshop sessions within a course), and bulk creation would trip this
# cross-course check. The column pair is treated as regular data from here on.
Sequel.migration do # rubocop:disable Metrics/BlockLength
  up do
    case database_type
    when :postgres
      alter_table(:events) do
        drop_constraint :events_start_at_end_at_key
      end
    when :sqlite
      # SQLite stores unnamed table-level UNIQUE as part of the CREATE TABLE
      # definition. The only way to remove it is to rebuild the table.
      transaction do
        run 'PRAGMA foreign_keys = OFF'
        create_table(:events_new) do
          primary_key :id
          foreign_key :course_id, :courses, on_delete: :cascade
          foreign_key :location_id, :locations, on_delete: :cascade
          String :name, null: false
          DateTime :start_at
          DateTime :end_at
          DateTime :created_at
          DateTime :updated_at
        end
        run 'INSERT INTO events_new SELECT id, course_id, location_id, name, ' \
            'start_at, end_at, created_at, updated_at FROM events'
        drop_table :events
        rename_table :events_new, :events
        run 'PRAGMA foreign_keys = ON'
      end
    end
  end

  down do # rubocop:disable Metrics/BlockLength
    case database_type
    when :postgres
      alter_table(:events) do
        add_unique_constraint %i[start_at end_at], name: :events_start_at_end_at_key
      end
    when :sqlite
      transaction do
        run 'PRAGMA foreign_keys = OFF'
        create_table(:events_new) do
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
        run 'INSERT INTO events_new SELECT id, course_id, location_id, name, ' \
            'start_at, end_at, created_at, updated_at FROM events'
        drop_table :events
        rename_table :events_new, :events
        run 'PRAGMA foreign_keys = ON'
      end
    end
  end
end
