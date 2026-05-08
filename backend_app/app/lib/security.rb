# frozen_string_literal: true

require 'rbnacl'
require 'base64'

module Tyto
  # Single boundary for cryptographic primitives. Application code calls into
  # this module — direct references to RbNaCl, OpenSSL::HMAC, SecureRandom, etc.
  # do not belong elsewhere in the codebase. See doc/security.md.
  #
  # Layers:
  #   - module functions: stateless utilities (random bytes, key generation)
  #   - Secret: symmetric authenticated encryption (encrypt / decrypt)
  #   - Signer: keyed message authentication (sign / valid?)
  module Security
    SECRET_KEY_BYTES  = RbNaCl::SecretBox.key_bytes
    SIGNING_KEY_BYTES = 32

    def self.random_bytes(count)
      RbNaCl::Random.random_bytes(count)
    end

    # Short string-safe unique identifier with `byte_count` bytes of entropy.
    # Use for non-crypto uniqueness needs (test fixtures, nonces, dedupe keys).
    # The internal encoding is opaque — callers should not depend on its form.
    def self.unique_id(byte_count = 8)
      random_bytes(byte_count).unpack1('H*')
    end

    def self.generate_secret_key
      Base64.strict_encode64(random_bytes(SECRET_KEY_BYTES))
    end

    def self.generate_signing_key
      Base64.strict_encode64(random_bytes(SIGNING_KEY_BYTES))
    end

    # Symmetric authenticated encryption keyed with a shared secret. Wire
    # format: `nonce ‖ ciphertext+tag` (binary). Callers handle outer encoding
    # (e.g., URL-safe base64) since framing varies by use case.
    class Secret
      class EncryptionError < StandardError; end

      def initialize(key:)
        @impl = RbNaCl::SecretBox.new(key)
      end

      def encrypt(plaintext)
        nonce = Security.random_bytes(@impl.nonce_bytes)
        nonce + @impl.encrypt(nonce, plaintext)
      end

      def decrypt(blob)
        nonce, ciphertext = blob.unpack("a#{@impl.nonce_bytes}a*")
        @impl.decrypt(nonce, ciphertext)
      rescue RbNaCl::CryptoError, ArgumentError => e
        raise EncryptionError, "Decryption failed: #{e.message}"
      end
    end

    # Keyed message authentication. 32-byte tags, constant-time verification.
    # Suitable for short, server-issued tokens (e.g., LocalGateway upload /
    # download tokens).
    class Signer
      TAG_SIZE = 32

      def initialize(key:)
        @key = key
      end

      def sign(message)
        RbNaCl::Hash::Blake2b.digest(message, key: @key, digest_size: TAG_SIZE)
      end

      def valid?(message, tag)
        return false unless tag.is_a?(String) && tag.bytesize == TAG_SIZE

        RbNaCl::Util.verify32(tag, sign(message))
      end
    end
  end
end
