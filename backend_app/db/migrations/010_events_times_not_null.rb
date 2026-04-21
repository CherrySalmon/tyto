# frozen_string_literal: true

require 'sequel'

# Require start_at and end_at on events — null times make no sense for an
# attendance event. Prerequisite audit in PLAN.feature-multi-event.md task 1.6b
# confirmed prod has zero rows with null time columns.
Sequel.migration do
  up do
    alter_table(:events) do
      set_column_not_null :start_at
      set_column_not_null :end_at
    end
  end

  down do
    alter_table(:events) do
      set_column_allow_null :start_at
      set_column_allow_null :end_at
    end
  end
end
