# frozen_string_literal: true

require 'sequel'

# Adds created_at/updated_at to accounts so the admin panel can show and sort
# by "added on". Nothing recorded when existing accounts were created, but
# nearly all of them came into being through a course enrollment, so each is
# backfilled with the creation time of the oldest course it is enrolled in.
# Accounts with no enrollment (the seeded admin) get the migration time.
Sequel.migration do
  up do
    alter_table(:accounts) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end

    first_course_at = from(:account_course_roles)
                      .join(:courses, id: :course_id)
                      .where(Sequel[:account_course_roles][:account_id] => Sequel[:accounts][:id])
                      .select { min(Sequel[:courses][:created_at]) }
    stamp = Sequel.function(:coalesce, first_course_at, Time.now.utc)

    from(:accounts).update(created_at: stamp, updated_at: stamp)
  end

  down do
    alter_table(:accounts) do
      drop_column :created_at
      drop_column :updated_at
    end
  end
end
