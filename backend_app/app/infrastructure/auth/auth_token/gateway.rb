# frozen_string_literal: true

require 'rbnacl'
require 'base64'

module Tyto
  module AuthToken
    # Gateway for encrypting and decrypting token payloads.
    # Handles RbNaCl SecretBox operations - knows nothing about domain objects.
    class Gateway
      class EncryptionError < StandardError; end

      def initialize(key = nil)
        @key = key || self.class.fetch_key
      end

      # Encrypts a payload string into a URL-safe Base64 token
      def encrypt(payload)
        secret_box = RbNaCl::SecretBox.new(@key)
        nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)
        encrypted = secret_box.encrypt(nonce, payload)

        Base64.urlsafe_encode64(nonce + encrypted)
      end

      # Decrypts a URL-safe Base64 token into the original payload string
      def decrypt(token)
        secret_box = RbNaCl::SecretBox.new(@key)
        decoded = Base64.urlsafe_decode64(token)
        nonce, encrypted = decoded.unpack("a#{secret_box.nonce_bytes}a*")

        secret_box.decrypt(nonce, encrypted)
      rescue RbNaCl::CryptoError, ArgumentError => e
        raise EncryptionError, "Decryption failed: #{e.message}"
      end

      # Generates a new encryption key (Base64 encoded)
      def self.generate_key
        key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
        Base64.strict_encode64(key)
      end

      # Fetches and decodes the key from environment
      def self.fetch_key
        base64_key = ENV.fetch('JWT_KEY') { raise EncryptionError, 'JWT_KEY not set in environment' }
        Base64.strict_decode64(base64_key)
      end
    end
  end
end
