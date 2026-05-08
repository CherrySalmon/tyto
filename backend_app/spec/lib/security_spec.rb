# frozen_string_literal: true

require_relative '../spec_helper'

# Tyto::Security — single boundary for all cryptographic primitives.
# Application code calls through here; no direct RbNaCl / OpenSSL / SecureRandom
# references elsewhere in the codebase. See doc/security.md.

describe 'Tyto::Security module functions' do
  describe '.random_bytes' do
    it 'returns the requested number of bytes' do
      _(Tyto::Security.random_bytes(16).bytesize).must_equal 16
      _(Tyto::Security.random_bytes(32).bytesize).must_equal 32
    end

    it 'produces independent draws' do
      _(Tyto::Security.random_bytes(32)).wont_equal Tyto::Security.random_bytes(32)
    end
  end

  describe '.unique_id' do
    it 'returns a non-empty string' do
      _(Tyto::Security.unique_id(4)).must_be_kind_of String
      _(Tyto::Security.unique_id(4)).wont_be_empty
    end

    it 'returns string-safe characters only' do
      _(Tyto::Security.unique_id(8)).must_match(/\A[\w-]+\z/)
    end

    it 'produces unique values' do
      _(Tyto::Security.unique_id(4)).wont_equal Tyto::Security.unique_id(4)
    end

    it 'has a default size when called without arguments' do
      _(Tyto::Security.unique_id).must_be_kind_of String
      _(Tyto::Security.unique_id).wont_be_empty
    end
  end

  describe '.generate_secret_key' do
    it 'returns a strict-base64 string decoding to 32 bytes' do
      key = Tyto::Security.generate_secret_key
      _(Base64.strict_decode64(key).bytesize).must_equal 32
    end

    it 'produces unique keys' do
      _(Tyto::Security.generate_secret_key).wont_equal Tyto::Security.generate_secret_key
    end
  end

  describe '.generate_signing_key' do
    it 'returns a strict-base64 string decoding to 32 bytes' do
      key = Tyto::Security.generate_signing_key
      _(Base64.strict_decode64(key).bytesize).must_equal 32
    end
  end
end

describe 'Tyto::Security::Secret' do
  let(:key)    { Base64.strict_decode64(Tyto::Security.generate_secret_key) }
  let(:secret) { Tyto::Security::Secret.new(key: key) }

  describe '#encrypt and #decrypt' do
    it 'round-trips a payload' do
      blob = secret.encrypt('hello world')
      _(secret.decrypt(blob)).must_equal 'hello world'
    end

    it 'produces different ciphertexts for the same plaintext' do
      _(secret.encrypt('same')).wont_equal secret.encrypt('same')
    end
  end

  describe '#decrypt' do
    it 'raises EncryptionError on tampered ciphertext' do
      blob = secret.encrypt('payload')
      tampered = blob.reverse
      _(-> { secret.decrypt(tampered) }).must_raise Tyto::Security::Secret::EncryptionError
    end

    it 'raises EncryptionError on truncated ciphertext' do
      _(-> { secret.decrypt('short') }).must_raise Tyto::Security::Secret::EncryptionError
    end

    it 'raises EncryptionError when the key does not match' do
      blob = secret.encrypt('payload')
      other_key = Base64.strict_decode64(Tyto::Security.generate_secret_key)
      other = Tyto::Security::Secret.new(key: other_key)
      _(-> { other.decrypt(blob) }).must_raise Tyto::Security::Secret::EncryptionError
    end
  end
end

describe 'Tyto::Security::Signer' do
  let(:key)    { Tyto::Security.random_bytes(32) }
  let(:other)  { Tyto::Security.random_bytes(32) }
  let(:signer) { Tyto::Security::Signer.new(key: key) }

  describe '#sign' do
    it 'returns a 32-byte tag' do
      tag = signer.sign('message')
      _(tag.bytesize).must_equal 32
    end

    it 'is deterministic for the same key + message' do
      _(signer.sign('m')).must_equal signer.sign('m')
    end

    it 'differs across keys' do
      other_signer = Tyto::Security::Signer.new(key: other)
      _(signer.sign('m')).wont_equal other_signer.sign('m')
    end
  end

  describe '#valid?' do
    it 'returns true for a tag produced by the same key' do
      tag = signer.sign('m')
      _(signer.valid?('m', tag)).must_equal true
    end

    it 'returns false for a tag produced by a different key' do
      other_signer = Tyto::Security::Signer.new(key: other)
      _(signer.valid?('m', other_signer.sign('m'))).must_equal false
    end

    it 'returns false on tampered message' do
      tag = signer.sign('m')
      _(signer.valid?('tampered', tag)).must_equal false
    end

    it 'returns false on a wrong-size tag' do
      _(signer.valid?('m', 'short')).must_equal false
      _(signer.valid?('m', "\x00" * 31)).must_equal false
      _(signer.valid?('m', "\x00" * 33)).must_equal false
    end

    it 'returns false on a nil tag' do
      _(signer.valid?('m', nil)).must_equal false
    end
  end
end
