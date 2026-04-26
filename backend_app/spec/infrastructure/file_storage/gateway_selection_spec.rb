# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tmpdir'

# 3.1d — Gateway selection: allowlist per R-P3.
#
# Source of truth for the environment is Roda's :environments plugin (already enabled
# in config/environment.rb), exposed as Tyto::Api.environment — a Symbol like
# :development, :test, :production. No ad-hoc ENV['RACK_ENV'] reads in the selector.
#
# `:development` and `:test` get LocalGateway. Every other environment value —
# `:production`, `:staging`, `:preview`, anything future — gets the AWS Gateway.
# Allowlist, not a `!= :production` denylist: a future staging env mustn't silently
# mount dev-only routes or skip the real S3 adapter.
#
# When credentials are missing for the selected backend, the selector raises rather
# than failing at first use.
#
# Credentials reach the selector via `Tyto::FileStorage.setup(...)`, called once at
# boot from `config/initializers/credentials.rb`. Tests inject test credentials via
# the same `setup` API — no ENV mutation.

# Shared helpers — kept top-level so each describe stays under Metrics/BlockLength.
module GatewaySelectionSpecSupport
  AWS_CREDS = {
    bucket: 'tyto-test-bucket',
    region: 'us-east-1',
    access_key_id: 'AKIA-TEST',
    secret_access_key: 'TEST-SECRET'
  }.freeze

  def setup_local_only
    Tyto::FileStorage.setup(
      aws: nil,
      local: {
        root: Dir.mktmpdir('tyto-selector-test-'),
        signing_key: 'selector-test-signing-key',
        base_url: 'http://localhost:9292'
      }
    )
  end

  def setup_aws_only
    Tyto::FileStorage.setup(aws: AWS_CREDS, local: nil)
  end

  # FileStorage credentials live on class instance variables — these tests
  # mutate that state, so snapshot at start and restore at end. Without this,
  # a downstream spec (e.g. routes that call IssueUploadGrants and reach
  # Tyto::FileStorage.build_gateway) sees a half-cleared state and 500s.
  def snapshot_file_storage
    {
      aws: Tyto::FileStorage.instance_variable_get(:@aws),
      local: Tyto::FileStorage.instance_variable_get(:@local)
    }
  end

  def restore_file_storage(snapshot)
    Tyto::FileStorage.setup(aws: snapshot[:aws], local: snapshot[:local])
  end
end

describe 'Tyto::FileStorage.build_gateway with allowlisted environments (R-P3)' do
  include GatewaySelectionSpecSupport

  before do
    @snapshot = snapshot_file_storage
    setup_local_only
  end
  after { restore_file_storage(@snapshot) }

  it 'returns LocalGateway for :development' do
    gateway = Tyto::FileStorage.build_gateway(environment: :development)
    _(gateway).must_be_kind_of Tyto::FileStorage::LocalGateway
  end

  it 'returns LocalGateway for :test' do
    gateway = Tyto::FileStorage.build_gateway(environment: :test)
    _(gateway).must_be_kind_of Tyto::FileStorage::LocalGateway
  end
end

describe 'Tyto::FileStorage.build_gateway for non-allowlisted environments (R-P3)' do
  include GatewaySelectionSpecSupport

  before do
    @snapshot = snapshot_file_storage
    setup_aws_only
  end
  after { restore_file_storage(@snapshot) }

  it 'returns AWS Gateway for :production' do
    gateway = Tyto::FileStorage.build_gateway(environment: :production)
    _(gateway).must_be_kind_of Tyto::FileStorage::Gateway
  end

  it 'returns AWS Gateway for :staging (not in allowlist, must NOT fall through to LocalGateway)' do
    gateway = Tyto::FileStorage.build_gateway(environment: :staging)
    _(gateway).must_be_kind_of Tyto::FileStorage::Gateway
  end

  it 'returns AWS Gateway for any other unknown environment value' do
    gateway = Tyto::FileStorage.build_gateway(environment: :preview)
    _(gateway).must_be_kind_of Tyto::FileStorage::Gateway
  end
end

describe 'Tyto::FileStorage.build_gateway error handling' do
  include GatewaySelectionSpecSupport

  before { @snapshot = snapshot_file_storage }
  after  { restore_file_storage(@snapshot) }

  it 'raises when AWS Gateway is selected but bucket is missing' do
    Tyto::FileStorage.setup(aws: GatewaySelectionSpecSupport::AWS_CREDS.merge(bucket: nil))
    _(-> { Tyto::FileStorage.build_gateway(environment: :production) })
      .must_raise Tyto::FileStorage::ConfigurationError
  end

  it 'raises when LocalGateway is selected but signing_key is missing' do
    Tyto::FileStorage.setup(local: { root: '/tmp/x', signing_key: nil, base_url: 'http://localhost' })
    _(-> { Tyto::FileStorage.build_gateway(environment: :development) })
      .must_raise Tyto::FileStorage::ConfigurationError
  end

  it 'falls back to Tyto::Api.environment when no kwarg is passed' do
    setup_local_only
    Tyto::Api.stub :environment, :test do
      gateway = Tyto::FileStorage.build_gateway
      _(gateway).must_be_kind_of Tyto::FileStorage::LocalGateway
    end
  end
end
