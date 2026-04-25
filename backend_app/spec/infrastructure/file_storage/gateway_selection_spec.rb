# frozen_string_literal: true

require_relative '../../spec_helper'

# 3.1d — Gateway selection: allowlist per R-P3.
#
# Source of truth for the environment is Roda's :environments plugin (already enabled
# in config/environment.rb), exposed as Tyto::Api.environment — a Symbol like
# :development, :test, :production. No ad-hoc ENV['RACK_ENV'] reads in the selector.
#
# `:development` and `:test` get LocalGateway (no AWS calls, real filesystem persistence
# under LOCAL_STORAGE_ROOT). Every other environment value — `:production`, `:staging`,
# `:preview`, anything future — gets the AWS Gateway. This is an allowlist, not a
# `!= :production` denylist: a future staging env mustn't silently mount dev-only
# routes or skip the real S3 adapter.
#
# When Gateway is selected and S3 config is missing from ENV, the selector raises
# (rather than failing at first use).

# Shared helpers — kept top-level so each describe stays under Metrics/BlockLength.
module GatewaySelectionSpecSupport
  S3_ENV_KEYS = %w[S3_BUCKET S3_REGION S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY].freeze
  LOCAL_ENV_KEYS = %w[LOCAL_STORAGE_ROOT LOCAL_STORAGE_SIGNING_KEY LOCAL_STORAGE_BASE_URL].freeze

  def with_env(overrides)
    saved = ENV.to_h
    overrides.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    saved_keys = saved.keys
    (overrides.keys - saved_keys).each { |k| ENV.delete(k) }
    saved.each { |k, v| ENV[k] = v }
  end

  def with_full_s3_config(&block)
    with_env(
      'S3_BUCKET' => 'tyto-test-bucket',
      'S3_REGION' => 'us-east-1',
      'S3_ACCESS_KEY_ID' => 'AKIA-TEST',
      'S3_SECRET_ACCESS_KEY' => 'TEST-SECRET',
      &block
    )
  end

  def with_full_local_config(&block)
    with_env(
      'LOCAL_STORAGE_ROOT' => Dir.mktmpdir('tyto-selector-test-'),
      'LOCAL_STORAGE_SIGNING_KEY' => 'selector-test-signing-key',
      'LOCAL_STORAGE_BASE_URL' => 'http://localhost:9292',
      &block
    )
  end
end

describe 'Tyto::FileStorage.build_gateway with allowlisted environments (R-P3)' do
  include GatewaySelectionSpecSupport

  it 'returns LocalGateway for :development' do
    with_full_local_config do
      gateway = Tyto::FileStorage.build_gateway(environment: :development)
      _(gateway).must_be_kind_of Tyto::FileStorage::LocalGateway
    end
  end

  it 'returns LocalGateway for :test' do
    with_full_local_config do
      gateway = Tyto::FileStorage.build_gateway(environment: :test)
      _(gateway).must_be_kind_of Tyto::FileStorage::LocalGateway
    end
  end
end

describe 'Tyto::FileStorage.build_gateway for non-allowlisted environments (R-P3)' do
  include GatewaySelectionSpecSupport

  it 'returns AWS Gateway for :production' do
    with_full_s3_config do
      gateway = Tyto::FileStorage.build_gateway(environment: :production)
      _(gateway).must_be_kind_of Tyto::FileStorage::Gateway
    end
  end

  it 'returns AWS Gateway for :staging (not in allowlist, must NOT fall through to LocalGateway)' do
    with_full_s3_config do
      gateway = Tyto::FileStorage.build_gateway(environment: :staging)
      _(gateway).must_be_kind_of Tyto::FileStorage::Gateway
    end
  end

  it 'returns AWS Gateway for any other unknown environment value' do
    with_full_s3_config do
      gateway = Tyto::FileStorage.build_gateway(environment: :preview)
      _(gateway).must_be_kind_of Tyto::FileStorage::Gateway
    end
  end
end

describe 'Tyto::FileStorage.build_gateway error handling' do
  include GatewaySelectionSpecSupport

  it 'raises when Gateway is selected but S3_BUCKET is missing' do
    with_env(GatewaySelectionSpecSupport::S3_ENV_KEYS.to_h { |k| [k, nil] }) do
      _(-> { Tyto::FileStorage.build_gateway(environment: :production) })
        .must_raise Tyto::FileStorage::ConfigurationError
    end
  end

  it 'raises when LocalGateway is selected but LOCAL_STORAGE_SIGNING_KEY is missing' do
    with_env(GatewaySelectionSpecSupport::LOCAL_ENV_KEYS.to_h { |k| [k, nil] }) do
      _(-> { Tyto::FileStorage.build_gateway(environment: :development) })
        .must_raise Tyto::FileStorage::ConfigurationError
    end
  end

  it 'falls back to Tyto::Api.environment when no kwarg is passed' do
    with_full_local_config do
      Tyto::Api.stub :environment, :test do
        gateway = Tyto::FileStorage.build_gateway
        _(gateway).must_be_kind_of Tyto::FileStorage::LocalGateway
      end
    end
  end
end
