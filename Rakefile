# frozen_string_literal: true

require 'rake/testtask'
require_relative './require_app'

desc 'Run all tests'
Rake::TestTask.new(:spec) do |t|
  t.pattern = 'backend_app/spec/**/*_spec.rb'
  t.warning = false
end

desc 'Run all tests'
task test: :spec

task default: :spec

desc 'Setup project for first time (install dependencies, configure secrets)'
task :setup do
  puts '==> Installing backend dependencies...'
  sh 'bundle config set --local without production'
  sh 'bundle install'

  puts "\n==> Installing frontend dependencies..."
  sh 'npm install'

  # Setup backend secrets
  secrets_src = 'backend_app/config/secrets_example.yml'
  secrets_dst = 'backend_app/config/secrets.yml'
  unless File.exist?(secrets_dst)
    puts "\n==> Copying #{secrets_src} to #{secrets_dst}..."
    cp secrets_src, secrets_dst
  end

  # Setup frontend environment
  env_src = 'frontend_app/.env.local.example'
  env_dst = 'frontend_app/.env.local'
  unless File.exist?(env_dst)
    puts "\n==> Copying #{env_src} to #{env_dst}..."
    cp env_src, env_dst
    puts '    Edit .env.local to set VUE_APP_GOOGLE_CLIENT_ID (see doc/google.md)'
  end

  puts "\n==> Setup complete! Next steps:"
  puts '    1. Generate JWT_KEY:  bundle exec rake generate:jwt_key'
  puts '       Copy the output into backend_app/config/secrets.yml'
  puts '    2. Set ADMIN_EMAIL in backend_app/config/secrets.yml (your Google email)'
  puts '    3. Set VUE_APP_GOOGLE_CLIENT_ID in frontend_app/.env.local (see doc/google.md)'
  puts '    4. Setup database: bundle exec rake db:setup'
end

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
    FileUtils.rm(db_filename) if File.exist?(db_filename)
    puts "Deleted #{db_filename}"
  end

  desc 'Setup database (migrate and seed)'
  task setup: %i[migrate seed]

  desc 'Reset database (drop, migrate, seed)'
  task reset: %i[drop migrate seed]
end

task :load_lib do
  require_app('lib')
end

namespace :generate do
  desc 'Generate JWT_KEY for secrets.yml'
  task jwt_key: :load_lib do
    puts "JWT_KEY: #{Todo::JWTCredential.generate_key}"
  end

  # Alias for backwards compatibility
  task msg_key: :jwt_key
end
