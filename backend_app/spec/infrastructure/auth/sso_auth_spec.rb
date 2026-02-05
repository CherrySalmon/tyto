# frozen_string_literal: true

require_relative '../../spec_helper'
require 'dry/monads'

describe 'SSOAuth' do
  include Dry::Monads[:result]

  # Helper to create mock HTTP response
  def mock_http_success(body)
    response = Minitest::Mock.new
    response.expect :is_a?, true, [Net::HTTPSuccess]
    response.expect :body, body
    response
  end

  def mock_http_error(code, message)
    response = Minitest::Mock.new
    response.expect :is_a?, false, [Net::HTTPSuccess]
    response.expect :code, code
    response.expect :message, message
    response
  end

  describe Tyto::SSOAuth::Gateway do
    let(:gateway) { Tyto::SSOAuth::Gateway.new }

    describe '#fetch_user_info (via parse_response)' do
      describe 'with successful response' do
        it 'returns Success with parsed user data' do
          google_data = { 'email' => 'user@example.com', 'name' => 'Test User' }
          response = mock_http_success(google_data.to_json)

          result = gateway.send(:parse_response, response)

          _(result).must_be_kind_of Dry::Monads::Result::Success
          _(result.value!['email']).must_equal 'user@example.com'
          _(result.value!['name']).must_equal 'Test User'
        end
      end

      describe 'with error response' do
        it 'returns Failure for HTTP error' do
          response = mock_http_error('401', 'Unauthorized')

          result = gateway.send(:parse_response, response)

          _(result).must_be_kind_of Dry::Monads::Result::Failure
          _(result.failure).must_include '401'
          _(result.failure).must_include 'Unauthorized'
        end
      end

      describe 'with invalid JSON response' do
        it 'returns Failure when body is not JSON' do
          response = mock_http_success('not valid json')

          result = gateway.send(:parse_response, response)

          _(result).must_be_kind_of Dry::Monads::Result::Failure
          _(result.failure).must_include 'Invalid response from Google'
        end
      end
    end

    describe 'constants' do
      it 'defines GOOGLE_USERINFO_URL' do
        _(Tyto::SSOAuth::Gateway::GOOGLE_USERINFO_URL).must_equal 'https://www.googleapis.com/oauth2/v3/userinfo'
      end
    end
  end

  describe Tyto::SSOAuth::Mapper do
    let(:mock_gateway) { Minitest::Mock.new }
    let(:mapper) { Tyto::SSOAuth::Mapper.new(gateway: mock_gateway) }

    describe '#load' do
      it 'transforms Google field names to domain names' do
        google_data = {
          'email' => 'user@example.com',
          'name' => 'Test User',
          'picture' => 'https://example.com/avatar.jpg',
          'access_token' => 'token123'
        }
        mock_gateway.expect :fetch_user_info, Success(google_data), ['valid_token']

        result = mapper.load('valid_token')

        mock_gateway.verify
        _(result).must_be_kind_of Dry::Monads::Result::Success
        _(result.value![:email]).must_equal 'user@example.com'
        _(result.value![:name]).must_equal 'Test User'
        _(result.value![:avatar]).must_equal 'https://example.com/avatar.jpg'
        _(result.value![:access_token]).must_equal 'token123'
      end

      it 'passes through gateway failures' do
        mock_gateway.expect :fetch_user_info, Failure('API error'), ['invalid_token']

        result = mapper.load('invalid_token')

        mock_gateway.verify
        _(result).must_be_kind_of Dry::Monads::Result::Failure
        _(result.failure).must_equal 'API error'
      end
    end

    describe Tyto::SSOAuth::Mapper::DataMapper do
      it 'maps picture to avatar' do
        data = { 'picture' => 'https://example.com/photo.jpg' }
        data_mapper = Tyto::SSOAuth::Mapper::DataMapper.new(data)

        result = data_mapper.to_hash

        _(result[:avatar]).must_equal 'https://example.com/photo.jpg'
        _(result.key?(:picture)).must_equal false
      end

      it 'handles nil values' do
        data = { 'email' => nil, 'name' => nil, 'picture' => nil }
        data_mapper = Tyto::SSOAuth::Mapper::DataMapper.new(data)

        result = data_mapper.to_hash

        _(result[:email]).must_be_nil
        _(result[:name]).must_be_nil
        _(result[:avatar]).must_be_nil
      end
    end
  end
end
