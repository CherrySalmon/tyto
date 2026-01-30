# frozen_string_literal: true

# rubocop:disable Bundler/DuplicatedGroup

source 'https://rubygems.org'
ruby File.read('.ruby-version').strip

# WEB APPLICATION
gem 'logger'
gem 'ostruct'
gem 'puma', '~>6.0'
gem 'roda', '~>3.0'
gem 'tilt'

# CONFIGURATION
gem 'figaro', '~>1.2'

# SECURITY AND AUTHENTICATION
gem 'google-id-token'
gem 'openssl', '~>3.3'
gem 'rack-ssl-enforcer'
gem 'rbnacl'

# VALIDATION AND DOMAIN TYPES
gem 'dry-monads', '~>1.6'
gem 'dry-operation', '~>1.0'
gem 'dry-struct', '~>1.6'
gem 'dry-validation', '~>1.10'
gem 'json_schemer'

# PRESENTATION
gem 'multi_json'
gem 'roar', '~>1.2'

# INFRASTRUCTURE
gem 'foreman', '~>0.0'
gem 'rake', '~>13.0'

# DATABASE
gem 'sequel', '~>5.0'

group :production do
  gem 'pg', '~>1.0'
end

group :development, :test do
  gem 'sqlite3', '~> 1.0'
end

# TESTING
group :development, :test do
  gem 'minitest'
  gem 'rack-test'
  gem 'simplecov', require: false
end

# DEBUGGING
group :development, :test do
  gem 'pry'
end

# CODE QUALITY
group :development do
  gem 'rubocop'
end

# rubocop:enable Bundler/DuplicatedGroup
