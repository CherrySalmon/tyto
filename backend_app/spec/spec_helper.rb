# frozen_string_literal: true

# 1. Environment setup
ENV['RACK_ENV'] = 'test'

# 2. Load application
require_relative '../../require_app'
require_app

# 3. Load test dependencies
require 'minitest/autorun'
require 'minitest/spec' # Enable spec-style describe/it blocks
require 'rack/test'

# 4. Load test helpers
require_relative 'support/test_helpers'

# 5. Database setup (run ONCE before all tests)
DB = Todo::Api.db
DB.tables.each { |table| DB[table].delete }

# Seed roles (same as production)
['admin', 'creator', 'member', 'owner', 'instructor', 'staff', 'student'].each do |role_name|
  Todo::Role.find_or_create(name: role_name)
end

# 6. Transaction wrapping (each test runs in rolled-back transaction)
class Minitest::Spec
  def run
    DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) do
      super
    end
  end
end
