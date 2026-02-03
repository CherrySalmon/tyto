# frozen_string_literal: true

require_relative '../../spec_helper'
require 'sequel'
require 'fileutils'

describe 'Database Setup from Scratch' do
  let(:project_root) { File.expand_path(__dir__ + '/../../../..') }
  let(:setup_db_path) { File.join(project_root, 'backend_app/db/store/test_setup.db') }
  let(:setup_db_url) { "sqlite://#{setup_db_path}" }
  let(:migration_path) { File.join(project_root, 'backend_app/db/migrations') }
  let(:seed_path) { File.join(project_root, 'backend_app/db/seeds/account_seeds.rb') }
  let(:expected_tables) do
    %i[
      roles
      accounts
      account_roles
      courses
      account_course_roles
      locations
      events
      attendances
      schema_info
    ] # schema_info <-- Sequel’s migration tracking table
  end
  let(:expected_roles) do
    %w[admin creator member owner instructor staff student]
  end

  before do
    # Ensure the database directory exists
    db_dir = File.dirname(setup_db_path)
    FileUtils.mkdir_p(db_dir) unless Dir.exist?(db_dir)
    
    # Clean up any existing test database to start fresh
    FileUtils.rm_f(setup_db_path)
    
    # Verify database doesn't exist before test
    _(File.exist?(setup_db_path)).must_equal false
  end

  after do
    # Ensure database connection is closed before deletion
    # Clean up the test database after the test
    FileUtils.rm_f(setup_db_path)
    
    # Verify database was deleted
    _(File.exist?(setup_db_path)).must_equal false
  end

  it 'sets up database from scratch with migrations and seeds' do
    # Verify database file doesn't exist yet
    _(File.exist?(setup_db_path)).must_equal false
    
    # Create a fresh database connection (this creates the file)
    db = nil
    begin
      db = Sequel.connect(setup_db_url)
      Sequel.extension :migration
      
      # Verify database file was created
      _(File.exist?(setup_db_path)).must_equal true

      # Load all migration files
      Dir.glob("#{migration_path}/*.rb").sort.each { |file| require file }

      # Run migrations
      Sequel::Migrator.run(db, migration_path)

      # Verify all tables exist
      actual_tables = db.tables.sort
      expected_tables_sorted = expected_tables.sort

      _(actual_tables).must_equal expected_tables_sorted

      # Verify schema_info has the expected version (Sequel integer migrator)
      migration_count = Dir.glob("#{migration_path}/*.rb").size
      current_version = db[:schema_info].get(:version)
      _(current_version).must_equal migration_count

      # Load seed file (this requires the app to be loaded)
      # We need to temporarily set up the environment so models use our db
      original_db = Tyto::Api.instance_variable_get(:@db)
      original_admin_email = ENV['ADMIN_EMAIL']
      Tyto::Api.instance_variable_set(:@db, db)

      # Point Sequel models at the setup database (set_dataset takes a dataset, not db)
      Tyto::Role.set_dataset(db[:roles])
      Tyto::Account.set_dataset(db[:accounts]) if defined?(Tyto::Account)

      # Set ADMIN_EMAIL for seed file
      ENV['ADMIN_EMAIL'] = 'test-admin@example.com'

      begin
        # Load the seed file
        load(seed_path) if File.exist?(seed_path)
      ensure
        # Restore original database connection and model datasets
        Tyto::Api.instance_variable_set(:@db, original_db)
        Tyto::Role.set_dataset(original_db[:roles]) if original_db
        Tyto::Account.set_dataset(original_db[:accounts]) if original_db && defined?(Tyto::Account)
        ENV['ADMIN_EMAIL'] = original_admin_email
      end

      # Verify roles were seeded
      role_names = db[:roles].select_map(:name).sort
      _(role_names).must_equal expected_roles.sort

      # Verify admin account was created (if seed file ran successfully)
      admin_accounts = db[:accounts].where(email: 'test-admin@example.com').all
      _(admin_accounts.length).must_be :>, 0

      # Verify database is usable - can insert and query data
      test_account_id = db[:accounts].insert(
        name: 'Test User',
        email: 'test@example.com',
        access_token: 'test_token'
      )
      account = db[:accounts].where(id: test_account_id).first
      _(account[:email]).must_equal 'test@example.com'
    ensure
      # Ensure database connection is closed
      db&.disconnect
    end
  end

  it 'can run migrations multiple times safely (idempotent)' do
    # Verify database file doesn't exist yet
    _(File.exist?(setup_db_path)).must_equal false
    
    # Create a fresh database connection (this creates the file)
    db = nil
    begin
      db = Sequel.connect(setup_db_url)
      Sequel.extension :migration
      
      # Verify database file was created
      _(File.exist?(setup_db_path)).must_equal true

      # Load all migration files
      Dir.glob("#{migration_path}/*.rb").sort.each { |file| require file }

      # Run migrations first time
      Sequel::Migrator.run(db, migration_path)
      first_run_tables = db.tables.sort

      # Run migrations again (should be idempotent)
      Sequel::Migrator.run(db, migration_path)
      second_run_tables = db.tables.sort

      # Tables should be the same
      _(second_run_tables).must_equal first_run_tables

      # Schema version should still match after second run (idempotent)
      migration_count = Dir.glob("#{migration_path}/*.rb").size
      current_version = db[:schema_info].get(:version)
      _(current_version).must_equal migration_count
    ensure
      # Ensure database connection is closed
      db&.disconnect
    end
  end
end
