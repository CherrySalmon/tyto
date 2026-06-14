# db/seeds/account_seeds.rb

require_relative '../../app/infrastructure/database/orm/role'
require_relative '../../app/infrastructure/database/orm/account'
require_relative '../../app/infrastructure/database/orm/course'
require_relative '../../app/infrastructure/database/orm/account_course'
require_relative '../../app/infrastructure/database/orm/location'
require_relative '../../app/infrastructure/database/orm/event'
require_relative 'e2e_fixtures'

# Define the role descriptions
role_descriptions = ['admin', 'creator', 'member', 'owner', 'instructor', 'staff', 'student']

# Iterate over the descriptions and create roles if they don't exist
role_descriptions.each do |desc|
  Tyto::Role.find_or_create(name: desc)
end

admin_user_data = {
  "name": " ",
  "email": ENV['ADMIN_EMAIL'],
  "roles": [
    "admin", "creator"
    ]
}

# Add a new account with the provided data
Tyto::Account.add_account(admin_user_data)

# ---------------------------------------------------------------------------
# E2E fixtures (browser-based user-acceptance tests)
#
# Deterministic accounts + one fully-enrolled course so Playwright specs can
# log in (via cookie injection) as each system role and each per-course
# enrollment role. Idempotent: safe to re-run against an already-seeded DB.
#
#   System roles  (admin/creator/member)      -> carried in the JWT credential
#   Course roles  (owner/instructor/staff/...) -> rows in account_course_roles
#
# Emails use the reserved-for-tests `e2e.test` domain so they can never collide
# with a real Google account. Mint a login credential for any of these with:
#   RACK_ENV=test bundle exec rake "generate:test_credential[e2e-owner@e2e.test]"
#
# The fixture *data* (accounts, course name, locations, event) lives in the pure
# `Tyto::E2EFixtures` module so the Playwright specs can import the same values
# (via `rake generate:e2e_seed_data`) and never drift from what is seeded here.
# ---------------------------------------------------------------------------

fx = Tyto::E2EFixtures
E2E_COURSE_NAME = fx::COURSE_NAME
E2E_LOCATION = fx::MAIN_HALL
E2E_EVENT_NAME = fx::EVENT_NAME

e2e_accounts = fx::ACCOUNTS.transform_values do |spec|
  # A non-blank avatar so App.vue renders the avatar popover (and its Logout
  # control) — the UI path E2E specs click. The URL need not resolve.
  avatar = "https://e2e.test/avatar/#{spec[:email].split('@').first}.png"
  account = Tyto::Account.first(email: spec[:email]) ||
            Tyto::Account.create(name: spec[:name], email: spec[:email], avatar: avatar)
  have = account.roles.map(&:name)
  (spec[:system_roles] - have).each do |role_name|
    role = Tyto::Role.first(name: role_name)
    account.add_role(role) if role
  end
  account
end

e2e_course = Tyto::Course.first(name: E2E_COURSE_NAME) ||
             Tyto::Course.create(name: E2E_COURSE_NAME, account_id: e2e_accounts[:owner].id)

fx::COURSE_ENROLLMENTS.each do |account_key, role_names|
  account = e2e_accounts[account_key]
  role_names.each do |role_name|
    role = Tyto::Role.first(name: role_name)
    next unless role

    exists = Tyto::AccountCourse.first(account_id: account.id, course_id: e2e_course.id, role_id: role.id)
    Tyto::AccountCourse.create(account_id: account.id, course_id: e2e_course.id, role_id: role.id) unless exists
  end
end

e2e_location = Tyto::Location.first(course_id: e2e_course.id, name: E2E_LOCATION[:name]) ||
               Tyto::Location.create(
                 course_id: e2e_course.id,
                 name: E2E_LOCATION[:name],
                 latitude: E2E_LOCATION[:latitude],
                 longitude: E2E_LOCATION[:longitude]
               )

# A second, event-free location the Locations spec can delete (task 14). Kept
# separate from E2E Main Hall so deleting it never cascades the seeded event.
unless Tyto::Location.first(course_id: e2e_course.id, name: fx::SPARE_ROOM[:name])
  Tyto::Location.create(
    course_id: e2e_course.id,
    name: fx::SPARE_ROOM[:name],
    latitude: fx::SPARE_ROOM[:latitude],
    longitude: fx::SPARE_ROOM[:longitude]
  )
end

# An attendance event whose window spans "now" (±1 day) so the student always
# has something to check into during a E2E run (task 11 — geo-fence check-in).
# Held at E2E Main Hall so its coordinates anchor the geo-fence.
unless Tyto::Event.first(course_id: e2e_course.id, name: E2E_EVENT_NAME)
  now = Time.now
  one_day = 24 * 60 * 60
  Tyto::Event.create(
    course_id: e2e_course.id,
    location_id: e2e_location.id,
    name: E2E_EVENT_NAME,
    start_at: now - one_day,
    end_at: now + one_day
  )
end

puts 'E2E fixtures seeded.'
