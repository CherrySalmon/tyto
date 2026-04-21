# frozen_string_literal: true

# Throwaway rehearsal script for PLAN task 1.6e.
# Exercises migrations 009 / 010 / 011 up -> down -> up on a populated DB,
# verifying that row data is preserved through every step.
# Usage: bundle exec ruby backend_app/db/rehearsal.rb

require 'sequel'
require 'digest'
require 'fileutils'

REHEARSAL_DB_PATH = 'backend_app/db/store/rehearsal.db'
MIGRATION_PATH    = 'backend_app/db/migrations'

FileUtils.rm_f(REHEARSAL_DB_PATH)
DB = Sequel.connect("sqlite://#{REHEARSAL_DB_PATH}")
Sequel.extension :migration

def migrate_to(target)
  Sequel::Migrator.run(DB, MIGRATION_PATH, target: target)
end

def events_snapshot
  rows = DB[:events]
          .select(:id, :course_id, :location_id, :name, :start_at, :end_at)
          .order(:id)
          .all
  digest = Digest::MD5.hexdigest(rows.inspect)
  [rows, digest]
end

def assert_eq(label, actual, expected)
  if actual == expected
    puts "  OK  #{label}"
  else
    puts "  FAIL #{label}: expected #{expected.inspect}, got #{actual.inspect}"
    exit 1
  end
end

puts '== Rehearsal: migrations 009 / 010 / 011 on populated dev DB =='

# Step 1: baseline schema (pre-slice-1, version 8)
migrate_to(8)
puts "Step 1: migrated to version 8 (pre-slice-1 baseline)"

# Step 2: populate — 2 courses, 2 locations, 8 events with distinct times
course_a = DB[:courses].insert(name: 'Course A', created_at: Time.now, updated_at: Time.now)
course_b = DB[:courses].insert(name: 'Course B', created_at: Time.now, updated_at: Time.now)
loc1 = DB[:locations].insert(course_id: course_a, name: 'Room 101',
                             created_at: Time.now, updated_at: Time.now)
loc2 = DB[:locations].insert(course_id: course_b, name: 'Room 202',
                             created_at: Time.now, updated_at: Time.now)

base_time = Time.new(2026, 5, 1, 9, 0, 0)
8.times do |i|
  DB[:events].insert(
    course_id: (i.even? ? course_a : course_b),
    location_id: (i.even? ? loc1 : loc2),
    name: "Lecture #{i + 1}",
    start_at: base_time + (i * 3600),
    end_at: base_time + (i * 3600) + 1800,
    created_at: Time.now,
    updated_at: Time.now
  )
end
puts "Step 2: populated 8 events across 2 courses / 2 locations"

rows0, digest0 = events_snapshot
puts "  baseline md5: #{digest0}"

# Step 3: migrate up to 11 (all three slice-1 migrations)
migrate_to(11)
puts 'Step 3: migrated up to 11 (009 + 010 + 011)'

rows1, digest1 = events_snapshot
assert_eq('post-up data preserved', digest1, digest0)
assert_eq('post-up row count', rows1.length, 8)

# Step 4: verify new schema permits same-(start,end) pairs (migration 009 effect)
dup_id = DB[:events].insert(
  course_id: course_a, location_id: loc1,
  name: 'Parallel Session', start_at: rows0[0][:start_at], end_at: rows0[0][:end_at],
  created_at: Time.now, updated_at: Time.now
)
puts "Step 4: inserted row #{dup_id} with duplicate (start_at, end_at) — 009 ok"

# Step 5: verify NOT NULL rejection (migration 010 effect)
begin
  DB[:events].insert(
    course_id: course_a, location_id: loc1,
    name: 'Null Times', start_at: nil, end_at: nil,
    created_at: Time.now, updated_at: Time.now
  )
  puts '  FAIL 010 did not reject nil times'
  exit 1
rescue Sequel::NotNullConstraintViolation
  puts 'Step 5: nil times rejected — 010 ok'
end

# Step 6: verify CHECK rejection (migration 011 effect)
begin
  DB[:events].insert(
    course_id: course_a, location_id: loc1,
    name: 'Backwards', start_at: base_time + 7200, end_at: base_time,
    created_at: Time.now, updated_at: Time.now
  )
  puts '  FAIL 011 did not reject start > end'
  exit 1
rescue Sequel::ConstraintViolation
  puts 'Step 6: start > end rejected — 011 ok'
end

# Step 7: clean up the duplicate row so rollback of 009 succeeds
DB[:events].where(id: dup_id).delete
puts "Step 7: removed duplicate row (so 009 down can re-add unique constraint)"

# Step 8: roll all three down to version 8
migrate_to(8)
puts 'Step 8: migrated down to 8 (rolled back 011 -> 010 -> 009)'

rows_down, digest_down = events_snapshot
assert_eq('post-down data preserved', digest_down, digest0)
assert_eq('post-down row count', rows_down.length, 8)

# Step 9: re-apply up to 11, confirm stable
migrate_to(11)
rows_final, digest_final = events_snapshot
assert_eq('final up data preserved', digest_final, digest0)
assert_eq('final up row count', rows_final.length, 8)

puts '== PASS: all three migrations round-trip cleanly with data intact =='

DB.disconnect
FileUtils.rm_f(REHEARSAL_DB_PATH)
