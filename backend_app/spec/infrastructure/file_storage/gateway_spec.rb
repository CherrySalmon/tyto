# frozen_string_literal: true

require_relative '../../spec_helper'
require 'json'
require 'base64'

# 3.1c — Gateway: AWS S3 adapter unit-tested with the SDK's built-in stub mode.
#
# Aws::S3::Client.new(stub_responses: true) validates request shapes against the real
# API and returns canned responses, with no HTTP. Presigned-POST and presigned-GET
# are pure local crypto, so they produce real signed payloads even in stub mode —
# which lets us assert real policy contents in tests 3 and 4 below.
#
# Why both this AND LocalGateway: stubs unit-test the adapter; LocalGateway gives
# the rest of the suite + dev environment a real persistence backend.

# Shared helpers for Gateway specs — kept top-level so each describe stays under Metrics/BlockLength.
module GatewaySpecSupport
  TEST_BUCKET = 'tyto-test-bucket'

  def stub_client
    Aws::S3::Client.new(
      stub_responses: true,
      region: 'us-east-1',
      access_key_id: 'AKIA-TEST',
      secret_access_key: 'TEST-SECRET'
    )
  end

  def build_gateway(client: stub_client)
    Tyto::FileStorage::Gateway.new(client:, bucket: TEST_BUCKET)
  end

  def decode_post_policy(fields)
    policy_b64 = fields['policy'] || fields[:policy]
    JSON.parse(Base64.decode64(policy_b64))
  end
end

describe 'Tyto::FileStorage::Gateway #presign_upload' do
  include GatewaySpecSupport

  let(:gateway) { build_gateway }
  let(:result)  { gateway.presign_upload(key: '1/2/3.pdf', allowed_extensions: ['.pdf']) }

  it 'returns Success with an upload_url and fields hash' do
    _(result.success?).must_equal true
    _(result.value![:upload_url]).must_be_kind_of String
    _(result.value![:fields]).must_be_kind_of Hash
  end

  it 'targets the configured bucket in the upload URL' do
    _(result.value![:upload_url]).must_include GatewaySpecSupport::TEST_BUCKET
  end

  it 'embeds content-length-range from MAX_SIZE_BYTES in the signed policy' do
    policy = decode_post_policy(result.value![:fields])
    size_cond = policy['conditions'].find { |c| c.is_a?(Array) && c.first == 'content-length-range' }
    _(size_cond).wont_be_nil
    _(size_cond[2]).must_equal Tyto::FileStorage::MAX_SIZE_BYTES
  end

  it 'pins the exact key in the signed policy' do
    policy = decode_post_policy(result.value![:fields])
    key_cond = policy['conditions'].find { |c| c.is_a?(Hash) && c.key?('key') }
    _(key_cond).wont_be_nil
    _(key_cond['key']).must_equal '1/2/3.pdf'
  end
end

describe 'Tyto::FileStorage::Gateway #presign_download' do
  include GatewaySpecSupport

  let(:gateway) { build_gateway }

  it 'returns Success carrying a download_url string' do
    result = gateway.presign_download(key: '1/2/3.pdf')
    _(result.success?).must_equal true
    _(result.value![:download_url]).must_be_kind_of String
  end

  it 'download_url targets the configured bucket and includes the key' do
    url = gateway.presign_download(key: '1/2/3.pdf').value![:download_url]
    _(url).must_include GatewaySpecSupport::TEST_BUCKET
    _(url).must_include '1/2/3.pdf'
  end
end

describe 'Tyto::FileStorage::Gateway #head' do
  include GatewaySpecSupport

  it 'returns Success when head_object succeeds' do
    client = stub_client
    client.stub_responses(:head_object, content_length: 11)
    _(build_gateway(client:).head(key: '1/2/3.pdf').success?).must_equal true
  end

  it 'returns Failure when head_object raises NotFound' do
    client = stub_client
    client.stub_responses(:head_object, 'NotFound')
    _(build_gateway(client:).head(key: 'missing.pdf').failure?).must_equal true
  end

  it 'returns Failure when head_object raises a generic service error' do
    client = stub_client
    client.stub_responses(:head_object, 'AccessDenied')
    _(build_gateway(client:).head(key: '1/2/3.pdf').failure?).must_equal true
  end
end

describe 'Tyto::FileStorage::Gateway #delete' do
  include GatewaySpecSupport

  it 'returns Success when delete_object succeeds' do
    client = stub_client
    client.stub_responses(:delete_object, {})
    _(build_gateway(client:).delete(key: '1/2/3.pdf').success?).must_equal true
  end

  it 'returns Failure when delete_object raises a service error' do
    client = stub_client
    client.stub_responses(:delete_object, 'AccessDenied')
    _(build_gateway(client:).delete(key: '1/2/3.pdf').failure?).must_equal true
  end
end
