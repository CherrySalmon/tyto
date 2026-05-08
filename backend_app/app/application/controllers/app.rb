# frozen_string_literal: true

require 'roda'
require 'json'
require_relative '../../infrastructure/database/orm/account'
require_relative './routes/account'
require_relative './routes/authentication'
require_relative './routes/course'
require_relative './routes/local_storage'
require 'rack/ssl-enforcer'

module Tyto
  class Api < Roda # rubocop:disable Style/Documentation
    plugin :render
    plugin :public, root: 'dist'
    plugin :all_verbs
    plugin :halt
    plugin :multi_route

    if ENV['RACK_ENV'] == 'production'
      use Rack::SslEnforcer, hsts: true
    end

    # Register the error_handler plugin
    plugin :error_handler do |e|
      case e
      when Sequel::NoMatchingRow
        response.status = 404
        { error: 'Not Found' }.to_json
      else
        response.status = 500
        { error: 'Internal Server Error', details: e.message }.to_json
      end
    end

    route do |r|
      r.public
      # API routes
      r.on 'api' do
        # All authentication-related routes are under 'api/auth'
        r.on 'auth' do
          r.run Routes::Authentication # Routes::Authentication is defined in 'routes/authentication.rb'
        end

        # All account-related routes are under 'api/account'
        r.on 'account' do
          r.run Routes::Accounts
        end

        # All course-related routes are under 'api/course'
        r.on 'course' do
          r.run Routes::Courses
        end

        # All current-event-related routes are under 'api/current_events'
        r.on 'current_events' do
          r.run Routes::CurrentEvents
        end

        # LocalGateway HTTP endpoints for development/test only — mounted in
        # the route tree (not at class-load) so the runtime allowlist guard
        # inside the route module gets a chance to halt with 404 in other
        # environments.
        r.on '_local_storage' do
          r.run Routes::LocalStorage
        end

        r.get do
          response['Content-Type'] = 'application/json'
          { success: true, message: 'Welcome to the Tyto API' }.to_json
        end
      end

      r.root do
        response['Cache-Control'] = 'no-cache'
        File.read(File.join('dist', 'index.html'))
      end

      r.get [String, true], [String, true], [String, true], [true] do |_parsed_request|
        response['Cache-Control'] = 'no-cache'
        File.read(File.join('dist', 'index.html'))
      end
    end
  end
end
