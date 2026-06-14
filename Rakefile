# frozen_string_literal: true

require 'rake/testtask'
require_relative './require_app'

namespace :spec do
  desc 'Run backend (Ruby/Minitest) tests'
  Rake::TestTask.new(:backend) do |t|
    t.pattern = 'backend_app/spec/**/*_spec.rb'
    t.warning = false
  end

  desc 'Run frontend (Vue/Vitest) tests'
  task :frontend do
    sh 'npm test'
  end

  desc 'Run browser-based E2E (Playwright). Resets+seeds the test DB, builds the frontend, then runs specs against :9292.'
  task :e2e do
    # Separate processes on purpose: `db:reset` in one process is broken for
    # SQLite. See .claude/plans/PLAN.test-ui.md "DB reset footgun".
    sh 'RACK_ENV=test bundle exec rake db:drop'
    sh 'RACK_ENV=test bundle exec rake db:migrate'
    sh 'RACK_ENV=test bundle exec rake db:seed'

    sh 'npm run prod'
    sh 'npx playwright test'
  end
end

desc 'Run all tests (backend + frontend)'
task spec: %w[spec:backend spec:frontend]

desc 'Run all tests'
task test: :spec

task default: :spec

desc 'Lint Ruby code with RuboCop'
task :style do
  sh 'bundle exec rubocop'
end

desc 'Audit bundled gems for known CVEs'
task :audit do
  sh 'bundle exec bundle-audit check --update'
end

desc 'Full pre-release check: tests + style + audit'
task quality: %i[spec style audit]

task :print_env do
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
end

desc 'Open interactive Tyto console (pry) with full app loaded'
task console: :print_env do
  sh 'pry -r ./console', verbose: false
end

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
  puts '    4. Setup databases:'
  puts '       bundle exec rake db:setup              # Development'
  puts '       RACK_ENV=test bundle exec rake db:setup # Test'
end

namespace :db do
  task :config do
    require('sequel')
    require_app('config', with_initializers: false)
  end

  desc 'Migrate the database to the latest version'
  task migrate: [:config] do
    Sequel.extension :migration

    # Set up the migration path
    migration_path = File.expand_path('backend_app/db/migrations', __dir__)

    # Run the migrations
    Dir.glob("#{migration_path}/*.rb").each { |file| require file }
    Sequel::Migrator.run(Tyto::Api.db, migration_path)
  end

  desc 'Seed the database with default data'
  task seed: [:config] do
    seed_path = File.expand_path('backend_app/db/seeds/account_seeds.rb')

    # Load and execute the seed script
    load(seed_path)
    puts 'Database has been seeded.'
  end

  desc 'Delete dev or test database file'
  task drop: [:config] do
    @app = Tyto::Api
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

namespace :run do
  desc 'Run backend API server for development'
  task :api do
    sh 'puma config.ru -t 1:5 -p 9292'
  end

  desc 'Run frontend webpack dev server'
  task :frontend do
    sh 'npm run dev'
  end
end

namespace :generate do
  desc 'Generate JWT_KEY for secrets.yml'
  task :jwt_key do
    require_relative 'backend_app/app/infrastructure/auth/auth_token/gateway'
    puts "JWT_KEY: #{Tyto::AuthToken::Gateway.generate_key}"
  end

  # Alias for backwards compatibility
  task msg_key: :jwt_key

  desc 'Generate LOCAL_STORAGE_SIGNING_KEY for secrets.yml (dev/test only)'
  task :local_storage_signing_key do
    require_relative 'backend_app/app/lib/security'
    puts "LOCAL_STORAGE_SIGNING_KEY: #{Tyto::Security.generate_signing_key}"
  end

  desc 'Mint an auth credential for a seeded account (E2E login bypass). Usage: rake "generate:test_credential[email@example.com]"'
  task :test_credential, [:email] do |_t, args|
    require('json')
    require_relative 'require_app'
    require_app # full app + initializers so AuthToken::Gateway is configured

    email = args[:email] or abort('Usage: rake "generate:test_credential[email@example.com]"')

    account = Tyto::Repository::Accounts.new.find_by_email_with_roles(email)
    abort("No account found for email: #{email}") unless account

    roles = account.roles.to_a
    credential = Tyto::AuthToken::Mapper.new.from_credentials(account.id, roles)

    # Emit a single JSON line so the Playwright login fixture can parse stdout.
    puts JSON.generate(
      id: account.id,
      name: account.name,
      email: account.email,
      avatar: account.avatar,
      roles: roles,
      credential: credential
    )
  end

  desc 'Mint credentials for every E2E account (@e2e.test) in one boot, keyed by role. Used by the Playwright E2E global setup.'
  task :e2e_credentials do
    require('json')
    require_relative 'require_app'
    require_app

    mapper = Tyto::AuthToken::Mapper.new
    accounts = Tyto::Account.where(Sequel.like(:email, '%@e2e.test')).all

    by_role = accounts.each_with_object({}) do |orm, acc|
      # 'e2e-owner@e2e.test' -> 'owner'
      role_key = orm.email.split('@').first.sub(/\Ae2e-/, '')
      roles = orm.roles.map(&:name)
      acc[role_key] = {
        id: orm.id,
        name: orm.name,
        email: orm.email,
        avatar: orm.avatar,
        roles: roles,
        credential: mapper.from_credentials(orm.id, roles)
      }
    end

    # Single JSON object on stdout: { "owner": {...}, "student": {...}, ... }
    puts JSON.generate(by_role)
  end

  desc 'Emit E2E seed-reference data (course/location/event names + coords, account emails) as JSON for the Playwright specs. Pure data — no app boot, no DB.'
  task :e2e_seed_data do
    require('json')
    require_relative 'backend_app/db/seeds/e2e_fixtures'

    # Single JSON object on stdout, consumed by e2e/seed-data.mjs. Mirrors the
    # seed fixtures so specs and the seeded DB never drift.
    puts JSON.generate(Tyto::E2EFixtures.as_json)
  end
end
