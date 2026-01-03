# frozen_string_literal: true

require_relative './require_app'

namespace :db do
  task :config do
    require('sequel')
    require_app('config')
  end

  desc 'Migrate the database to the latest version'
  task migrate: [:config] do
    Sequel.extension :migration

    # Set up the migration path
    migration_path = File.expand_path('backend_app/db/migration', __dir__)

    # Run the migrations
    Dir.glob("#{migration_path}/*.rb").each { |file| require file }
    Sequel::Migrator.run(Todo::Api.db, migration_path)
  end

  desc 'Seed the database with default data'
  task seed: [:config] do
    seed_path = File.expand_path('backend_app/db/account_seeds.rb')

    # Load and execute the seed script
    load(seed_path)
    puts 'Database has been seeded.'
  end

  desc 'Delete dev or test database file'
  task drop: [:config] do
    @app = BackendApp::Api
    if @app.environment == :production
      puts 'Cannot wipe production database!'
      return
    end

    db_filename = "backend_app/db/store/#{@app.environment}.db"
    FileUtils.rm(db_filename)
    puts "Deleted #{db_filename}"
  end
end

task :load_lib do
  require_app('lib')
end

namespace :generate do
  desc 'Create rbnacl key'
  task :msg_key => :load_lib do
    puts "New MSG_KEY (base64): #{Todo::JWTCredential.generate_key}"
  end
end
