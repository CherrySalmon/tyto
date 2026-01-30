require 'sequel'
require 'figaro'
require 'roda'
require 'logger'
module Tyto
  # Configuration for the API
  class Api < Roda
    plugin :environments

    # load config secrets into local environment variables (ENV)
    Figaro.application = Figaro::Application.new(
      environment: environment, # rubocop:disable Style/HashSyntax
      path: File.expand_path('backend_app/config/secrets.yml')
    )
    Figaro.load

    # Make the environment variables accessible to other classes
    def self.config = Figaro.env
    db_url = ENV['DATABASE_URL']

    # Ensure all times are handled in UTC at the DB layer
    Sequel.default_timezone = :utc
    Sequel.application_timezone = :utc

    # Only log SQL in development, not in test
    db_logger = environment == :development ? Logger.new($stderr) : nil
    @db = Sequel.connect(db_url, logger: db_logger)
    def self.db = @db # rubocop:disable Style/TrivialAccessors
  end
end
