# frozen_string_literal: true

require 'aws-sdk-s3'

module Tyto
  # Boundary code for binary file storage (presign, head, delete).
  # Selects between LocalGateway (dev/test) and the AWS S3 Gateway.
  #
  # Credentials are loaded once at boot via `Tyto::FileStorage.setup(...)`
  # (called from `config/initializers/credentials.rb`). This module never
  # reads ENV itself. Tests can call `setup` directly with fresh values.
  module FileStorage
    class ConfigurationError < StandardError; end

    LOCAL_ENVIRONMENTS = %i[development test].freeze
    LOCAL_KEYS = %i[root signing_key base_url].freeze
    AWS_KEYS = %i[bucket region access_key_id secret_access_key].freeze

    class << self
      def setup(aws: nil, local: nil)
        @aws = aws
        @local = local
        @local_gateway = nil
      end

      def reset!
        @aws = nil
        @local = nil
        @local_gateway = nil
      end

      # Selects the right gateway adapter for the current environment.
      # Allowlist: only :development and :test get LocalGateway; every other
      # environment (including :production, :staging, :preview) gets the AWS
      # Gateway. Configuration errors raise here rather than at first use, so
      # misconfigured deploys fail at boot.
      #
      # The LocalGateway is memoized so its single-use nonce cache is shared
      # across requests within the same process. The AWS Gateway is stateless,
      # so memoizing it would buy nothing.
      def build_gateway(environment: Tyto::Api.environment)
        if LOCAL_ENVIRONMENTS.include?(environment)
          @local_gateway ||= build_local_gateway
        else
          build_aws_gateway
        end
      end

      private

      def build_local_gateway
        ensure_present!(@local, LOCAL_KEYS, 'local-storage')
        LocalGateway.new(**@local)
      end

      def build_aws_gateway
        ensure_present!(@aws, AWS_KEYS, 'S3')
        client = Aws::S3::Client.new(
          region: @aws[:region],
          access_key_id: @aws[:access_key_id],
          secret_access_key: @aws[:secret_access_key]
        )
        Gateway.new(client:, bucket: @aws[:bucket])
      end

      def ensure_present!(creds, keys, label)
        if creds.nil?
          raise ConfigurationError,
                "#{label} credentials not configured (call Tyto::FileStorage.setup at boot)"
        end
        keys.each do |k|
          raise ConfigurationError, "#{label} credential :#{k} is missing" if creds[k].nil?
        end
      end
    end
  end
end
