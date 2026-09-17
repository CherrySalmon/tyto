# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'sequel'
require 'fileutils'

# Two requests can both see an email as missing and both insert it; only the
# database can close that race. Migration 017 adds the unique index.
describe 'Migration 017: unique index on accounts.email' do
  let(:project_root) { File.expand_path("#{__dir__}/../../../../..") }
  let(:db_path) { File.join(project_root, 'backend_app/db/store/test_migration_017.db') }
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

  it 'rejects a second account with the same email once applied' do
    with_scratch_db do |db|
      Sequel::Migrator.run(db, migration_path, target: 17)
      db[:accounts].insert(email: 'same@example.com')

      _(proc { db[:accounts].insert(email: 'same@example.com') }).must_raise Sequel::UniqueConstraintViolation
    end
  end

  it 'refuses to apply while duplicates exist, so bad data is found before the index' do
    with_scratch_db do |db|
      Sequel::Migrator.run(db, migration_path, target: 16)
      db[:accounts].insert(email: 'dupe@example.com')
      db[:accounts].insert(email: 'dupe@example.com')

      _(proc { Sequel::Migrator.run(db, migration_path, target: 17) }).must_raise Sequel::DatabaseError
      _(db[:schema_info].first[:version]).must_equal 16
    end
  end
end
