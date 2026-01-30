# frozen_string_literal: true

require 'roda'
require 'json'
require_relative '../infrastructure/database/orm/account'
require_relative '../controllers/routes/account'
require_relative '../controllers/routes/authentication'
require_relative '../controllers/routes/course'
require 'rack/ssl-enforcer'

module Todo
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
      # Nesting todos and auth under the 'api' route
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

        # All curren-event-related routes are under 'api/course'
        r.on 'current_event' do
          r.run Routes::CurrentEvents
        end

        r.get do
          response['Content-Type'] = 'application/json'
          { success: true, message: 'Welcome to the Todo API' }.to_json
        end
      end
  
      r.root do
        File.read(File.join('dist', 'index.html'))
      end

      r.get [String, true], [String, true], [String, true], [true] do |_parsed_request|
        File.read(File.join('dist', 'index.html'))
      end
    end
  end
end
