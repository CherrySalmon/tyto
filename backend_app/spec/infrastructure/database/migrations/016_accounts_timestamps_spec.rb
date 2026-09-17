# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'sequel'
require 'fileutils'

# Runs migration 016 against a scratch SQLite file that holds pre-existing
# accounts, so the backfill rule can be checked without touching the suite DB.
describe 'Migration 016: accounts timestamps backfill' do
  let(:project_root) { File.expand_path("#{__dir__}/../../../../..") }
  let(:db_path) { File.join(project_root, 'backend_app/db/store/test_migration_016.db') }
  let(:migration_path) { File.join(project_root, 'backend_app/db/migrations') }

  before { FileUtils.rm_f(db_path) }
  after { FileUtils.rm_f(db_path) }

  def with_scratch_db
    db = Sequel.connect("sqlite://#{db_path}")
    Sequel.extension :migration
    Dir.glob("#{migration_path}/*.rb").sort.each { |file| require file }
    yield db
  ensure
    db&.disconnect
  end

  it 'stamps each pre-existing account with its oldest enrolled course creation time, else the migration time' do
    with_scratch_db do |db|
      Sequel::Migrator.run(db, migration_path, target: 15)

      role_id = db[:roles].insert(name: 'student')
      enrolled = db[:accounts].insert(email: 'enrolled@example.com')
      unenrolled = db[:accounts].insert(email: 'lonely@example.com')
      old_course = db[:courses].insert(name: 'Old', created_at: Time.utc(2024, 2, 1), updated_at: Time.utc(2024, 2, 1))
      new_course = db[:courses].insert(name: 'New', created_at: Time.utc(2025, 9, 1), updated_at: Time.utc(2025, 9, 1))
      db[:account_course_roles].insert(account_id: enrolled, course_id: new_course, role_id:)
      db[:account_course_roles].insert(account_id: enrolled, course_id: old_course, role_id:)

      before = Time.now.utc - 1
      Sequel::Migrator.run(db, migration_path, target: 16)

      stamped = db[:accounts].where(id: enrolled).first
      _(Time.parse(stamped[:created_at].to_s).utc).must_equal Time.utc(2024, 2, 1)
      _(Time.parse(stamped[:updated_at].to_s).utc).must_equal Time.utc(2024, 2, 1)

      lonely = db[:accounts].where(id: unenrolled).first
      _(Time.parse(lonely[:created_at].to_s).utc).must_be :>=, before
      _(Time.parse(lonely[:updated_at].to_s).utc).must_be :>=, before
    end
  end
end
