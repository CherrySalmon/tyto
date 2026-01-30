require 'rbnacl'
require 'base64'
require 'json'

module Todo
  class JWTCredential
    class ArgumentError < StandardError; end
    # Generates a new key for encryption/decryption
    def self.generate_key
      key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
      Base64.strict_encode64(key) # Return Base64 encoded key
    end

    # Generates a JWT for an account with given ID and roles
    def self.generate_jwt(account_id, roles)
      validate_input(account_id, roles)

      key = fetch_decoded_key
      secret_box = RbNaCl::SecretBox.new(key)
      
      payload = { account_id: account_id, roles: roles }.to_json
      nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)
      encrypted_payload = secret_box.encrypt(nonce, payload)

      Base64.urlsafe_encode64(nonce + encrypted_payload)
    end

    def self.decode_jwt(auth_header)
      raise ArgumentError, 'Authorization header cannot be nil or empty' unless auth_header && auth_header.start_with?('Bearer ')
  
      token = auth_header.split(' ').last
      key = fetch_decoded_key
      secret_box = RbNaCl::SecretBox.new(key)
      
      decoded_data = Base64.urlsafe_decode64(token)
      nonce, encrypted_payload = decoded_data.unpack("a#{secret_box.nonce_bytes}a*")
      decrypted_payload = secret_box.decrypt(nonce, encrypted_payload)
      
      JSON.parse(decrypted_payload)
    rescue RbNaCl::CryptoError, JSON::ParserError => e
      # Handle decryption failure or invalid JSON format
      { error: 'Decryption failed', details: e.message }
    end

    private

    # Validates the input for the generate_jwt method
    def self.validate_input(account_id, roles)
      raise ArgumentError, 'Account ID cannot be nil or empty' if account_id.to_s.strip.empty?
      raise ArgumentError, 'Roles cannot be nil or empty' if roles.nil? || roles.empty?
    end

    # Fetches and decodes the JWT key from environment variables
    def self.fetch_decoded_key
      base64_key = ENV['JWT_KEY']
      raise 'JWT_KEY is not set in the environment.' unless base64_key

      Base64.strict_decode64(base64_key)
    end
  end
end
