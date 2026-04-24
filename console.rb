# frozen_string_literal: true

# Loader for `bundle exec rake console` — boots pry with the full Tyto app
# in scope (Tyto::Api, Tyto::DB access via Tyto::Api.db, repositories,
# domain entities, ORM models). Also useful locally for ad-hoc debugging.

# Load config first — this creates Tyto::Api.db with the dev SQL logger attached
# (tuned for web-server traces; pure noise in an interactive REPL). Strip the
# logger *before* require_app loads the ORM models, otherwise Sequel's model
# schema-introspection floods the console at startup.
Dir.glob('./backend_app/config/**/*.rb').each { |file| require_relative file }
Tyto::Api.db.loggers.clear if Tyto::Api.db.respond_to?(:loggers)

require_relative './require_app'
require_app

def app = Tyto::Api

unless app.environment == :production
  require 'rack/test'
  include Rack::Test::Methods # rubocop:disable Style/MixinUsage
end
