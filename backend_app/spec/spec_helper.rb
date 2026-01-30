# frozen_string_literal: true

# Code coverage (must load before application code)
require 'simplecov'
SimpleCov.start

# Environment setup
ENV['RACK_ENV'] = 'test'

# Load application and dependencies
require_relative '../../require_app'
require_app

require 'minitest/autorun'
require 'minitest/spec' # Enable spec-style describe/it blocks
require 'rack/test'

require_relative 'support/test_helpers'

# Database setup (run ONCE before all tests)
DB = Tyto::Api.db
DB.tables.each { |table| DB[table].delete }

# Seed roles (same as production)
%w[admin creator member owner instructor staff student].each do |role_name|
  Tyto::Role.find_or_create(name: role_name)
end

# Transaction wrapping (each test runs in rolled-back transaction)
class Minitest::Spec # rubocop:disable Style/ClassAndModuleChildren
  def run
    DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) do
      super
    end
  end
end
