# frozen_string_literal: true

require 'net/http'
require 'json'
require 'dry/monads'

module Tyto
  module SSOAuth
    # Gateway for Google OAuth HTTP operations.
    # Handles raw HTTP communication with Google APIs.
    class Gateway
      include Dry::Monads[:result]

      GOOGLE_USERINFO_URL = 'https://www.googleapis.com/oauth2/v3/userinfo'

      # Fetch raw user info from Google OAuth
      # @param access_token [String] Google OAuth access token
      # @return [Dry::Monads::Result] Success(Hash) with raw data or Failure(String)
      def fetch_user_info(access_token)
        response = request_user_info(access_token)
        parse_response(response)
      rescue StandardError => e
        Failure("Google API error: #{e.message}")
      end

      private

      def request_user_info(access_token)
        uri = URI(GOOGLE_USERINFO_URL)
        uri.query = URI.encode_www_form(access_token:)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)

        http.request(request)
      end

      def parse_response(response)
        unless response.is_a?(Net::HTTPSuccess)
          return Failure("Google API returned #{response.code}: #{response.message}")
        end

        user_data = JSON.parse(response.body)
        Success(user_data)
      rescue JSON::ParserError => e
        Failure("Invalid response from Google: #{e.message}")
      end
    end
  end
end
