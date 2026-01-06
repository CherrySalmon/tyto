# frozen_string_literal: true

source 'https://rubygems.org'

gem 'figaro', '~>1.2'
gem 'foreman', '~>0.0'
gem 'json_schemer'
gem 'puma', '~>6.0'
gem 'rake', '~>13.0'
gem 'roda', '~>3.0'
gem 'sequel', '~>5.0'
gem 'tilt'
gem 'google-id-token'
gem 'dry-validation', '~>1.10'
gem 'rack-ssl-enforcer'
gem 'rbnacl'
gem 'openssl', '~>3.3'

group :production do
  gem 'pg', '~>1.0'
end

group :development, :test do
  gem 'minitest'
  gem 'pry'
  gem 'rack-test'
  gem 'sqlite3', '~> 1.0'
end

group :development do
  gem 'rubocop'
end
