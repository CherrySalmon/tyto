# frozen_string_literal: true

require 'json'
require 'dry/monads'

module Todo
  module Routes
    class CurrentEvents < Roda
      include Dry::Monads[:result]

      plugin :all_verbs
      plugin :request_headers

      route do |r|
        r.on do
          auth_header = r.headers['Authorization']
          requestor = JWTCredential.decode_jwt(auth_header)

          # GET api/current_event/
          r.get do
            case Service::Events::FindActiveEvents.new.call(requestor:, time: Time.now)
            in Success(api_result)
              response.status = api_result.http_status_code
              { success: true, data: Representer::EventsList.from_entities(api_result.message).to_array }.to_json
            in Failure(api_result)
              response.status = api_result.http_status_code
              api_result.to_json
            end
          end
        rescue JWTCredential::ArgumentError => e
          response.status = 400
          response.write({ error: 'Token error', details: e.message }.to_json)
          r.halt
        rescue StandardError => e
          response.status = 500
          response.write({ error: 'Internal server error', details: e.message }.to_json)
          r.halt
        end
      end
    end
  end
end
