# frozen_string_literal: true

require_relative '../spec_helper'

describe Todo::JWTCredential do
  describe '.generate_jwt' do
    it 'returns a string token' do
      token = Todo::JWTCredential.generate_jwt(1, ['creator'])
      _(token).must_be_kind_of String
      _(token).wont_be_empty
    end

    it 'raises error with nil account_id' do
      _(-> { Todo::JWTCredential.generate_jwt(nil, ['creator']) }).must_raise Todo::JWTCredential::ArgumentError
    end

    it 'raises error with empty roles' do
      _(-> { Todo::JWTCredential.generate_jwt(1, []) }).must_raise Todo::JWTCredential::ArgumentError
    end
  end

  describe '.decode_jwt' do
    it 'returns account_id and roles from valid token' do
      token = Todo::JWTCredential.generate_jwt(42, ['admin', 'creator'])
      result = Todo::JWTCredential.decode_jwt("Bearer #{token}")

      _(result['account_id']).must_equal 42
      _(result['roles']).must_equal ['admin', 'creator']
    end

    it 'raises error for invalid base64 token' do
      _(-> { Todo::JWTCredential.decode_jwt('Bearer invalid_token') }).must_raise ArgumentError
    end

    it 'raises error without Bearer prefix' do
      token = Todo::JWTCredential.generate_jwt(1, ['creator'])
      _(-> { Todo::JWTCredential.decode_jwt(token) }).must_raise Todo::JWTCredential::ArgumentError
    end
  end
end
