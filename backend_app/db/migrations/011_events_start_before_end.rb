# frozen_string_literal: true

require 'sequel'

# Enforce start_at <= end_at at the schema layer. Inclusive so zero-duration
# placeholder events remain legal. Prerequisite audit in
# PLAN.feature-multi-event.md task 1.6f-audit confirmed prod has zero rows
# violating this constraint.
Sequel.migration do
  up do
    alter_table(:events) do
      add_constraint(:start_before_end) { start_at <= end_at }
    end
  end

  down do
    alter_table(:events) do
      drop_constraint(:start_before_end)
    end
  end
end
