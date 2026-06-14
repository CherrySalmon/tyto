# frozen_string_literal: true

# db/seeds/e2e_fixtures.rb
#
# Single source of truth for the E2E fixture *data* (deterministic accounts,
# the enrolled course, its locations and live event). Requiring this file does
# NO database work — it only defines frozen data. Two consumers read from it so
# the seed and the Playwright specs can never drift:
#
#   * account_seeds.rb            — builds the fixtures in the DB from these.
#   * rake generate:e2e_seed_data — emits `as_json` for the JS specs to import
#                                    (e2e/seed-data.mjs), regenerated every run.
#
# Change a name or coordinate here and both the seeded DB and the specs that
# reference it move together, automatically.
module Tyto
  module E2EFixtures
    # System roles (admin/creator/member) are carried in the JWT credential.
    # Emails use the reserved-for-tests `e2e.test` domain so they can never
    # collide with a real Google account.
    ACCOUNTS = {
      admin:      { name: 'E2E Admin',      email: 'e2e-admin@e2e.test',      system_roles: %w[admin creator member] },
      creator:    { name: 'E2E Creator',    email: 'e2e-creator@e2e.test',    system_roles: %w[creator member] },
      owner:      { name: 'E2E Owner',      email: 'e2e-owner@e2e.test',      system_roles: %w[member] },
      instructor: { name: 'E2E Instructor', email: 'e2e-instructor@e2e.test', system_roles: %w[member] },
      staff:      { name: 'E2E Staff',      email: 'e2e-staff@e2e.test',      system_roles: %w[member] },
      student:    { name: 'E2E Student',    email: 'e2e-student@e2e.test',    system_roles: %w[member] },
      # Enrolled with TWO course roles so the SingleCourse "view as role" switcher
      # has more than one option to switch between (task 8a).
      multi:      { name: 'E2E Multi-role', email: 'e2e-multi@e2e.test',      system_roles: %w[member] }
    }.freeze

    # Per-course enrollment: account key => course role(s). admin + creator stay
    # unenrolled so specs have a "not a member of this course" actor to assert on.
    COURSE_ENROLLMENTS = {
      owner: %w[owner],
      instructor: %w[instructor],
      staff: %w[staff],
      student: %w[student],
      multi: %w[instructor student]
    }.freeze

    COURSE_NAME = 'E2E Course'

    # Geo-fenced location anchoring the live event's attendance check-in.
    MAIN_HALL = { name: 'E2E Main Hall', latitude: 25.0330, longitude: 121.5654 }.freeze

    # A second, event-free location the Locations spec can delete (task 14).
    # Separate from Main Hall so deleting it never cascades the seeded event.
    SPARE_ROOM = { name: 'E2E Spare Room', latitude: 25.0340, longitude: 121.5660 }.freeze

    EVENT_NAME = 'E2E Live Session'

    # Flattened, JS-idiomatic (camelCase) view emitted by the rake task and
    # imported by e2e/seed-data.mjs. Only the values the specs reference.
    def self.as_json
      {
        course: { name: COURSE_NAME },
        event: { name: EVENT_NAME },
        mainHall: MAIN_HALL,
        spareRoom: SPARE_ROOM,
        accounts: ACCOUNTS.transform_values { |spec| { name: spec[:name], email: spec[:email] } }
      }
    end
  end
end
