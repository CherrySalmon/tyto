# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::AuthToken::Mapper do
  let(:mapper) { Tyto::AuthToken::Mapper.new }
  let(:requestor) { Tyto::Domain::Accounts::Values::Requestor.new(account_id: 42, roles: ['admin', 'creator']) }

  describe '#to_token' do
    it 'returns a string token from Requestor' do
      token = mapper.to_token(requestor)

      _(token).must_be_kind_of String
      _(token).wont_be_empty
    end

    it 'raises MappingError with nil requestor' do
      _(-> { mapper.to_token(nil) }).must_raise Tyto::AuthToken::Mapper::MappingError
    end
  end

  describe '#from_credentials' do
    it 'returns a string token from raw credentials' do
      token = mapper.from_credentials(1, ['creator'])

      _(token).must_be_kind_of String
      _(token).wont_be_empty
    end

    it 'raises MappingError with nil account_id' do
      _(-> { mapper.from_credentials(nil, ['creator']) }).must_raise Tyto::AuthToken::Mapper::MappingError
    end

    it 'raises MappingError with empty roles' do
      _(-> { mapper.from_credentials(1, []) }).must_raise Tyto::AuthToken::Mapper::MappingError
    end
  end

  describe '#from_auth_header' do
    it 'returns Requestor from valid token' do
      token = mapper.to_token(requestor)
      result = mapper.from_auth_header("Bearer #{token}")

      _(result).must_be_kind_of Tyto::Domain::Accounts::Values::Requestor
      _(result.account_id).must_equal 42
      _(result.roles).must_equal ['admin', 'creator']
    end

    it 'raises MappingError for invalid token' do
      _(-> { mapper.from_auth_header('Bearer invalid_token') }).must_raise Tyto::AuthToken::Mapper::MappingError
    end

    it 'raises MappingError without Bearer prefix' do
      token = mapper.to_token(requestor)
      _(-> { mapper.from_auth_header(token) }).must_raise Tyto::AuthToken::Mapper::MappingError
    end

    it 'raises MappingError for nil auth header' do
      _(-> { mapper.from_auth_header(nil) }).must_raise Tyto::AuthToken::Mapper::MappingError
    end
  end
end
