# db/seeds/account_seeds.rb

require_relative '../../app/infrastructure/database/orm/role'
require_relative '../../app/infrastructure/database/orm/account'
require_relative '../../app/infrastructure/database/orm/course'
require_relative '../../app/infrastructure/database/orm/account_course'
require_relative '../../app/infrastructure/database/orm/location'
require_relative '../../app/infrastructure/database/orm/event'

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
# ---------------------------------------------------------------------------

E2E_ACCOUNTS = {
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
E2E_COURSE_ENROLLMENTS = {
  owner: %w[owner],
  instructor: %w[instructor],
  staff: %w[staff],
  student: %w[student],
  multi: %w[instructor student]
}.freeze
E2E_COURSE_NAME = 'E2E Course'
E2E_LOCATION = { name: 'E2E Main Hall', latitude: 25.0330, longitude: 121.5654 }.freeze
E2E_EVENT_NAME = 'E2E Live Session'

e2e_accounts = E2E_ACCOUNTS.transform_values do |spec|
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

E2E_COURSE_ENROLLMENTS.each do |account_key, role_names|
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
unless Tyto::Location.first(course_id: e2e_course.id, name: 'E2E Spare Room')
  Tyto::Location.create(course_id: e2e_course.id, name: 'E2E Spare Room', latitude: 25.0340, longitude: 121.5660)
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
