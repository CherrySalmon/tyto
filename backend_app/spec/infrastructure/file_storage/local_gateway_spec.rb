# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tmpdir'
require 'fileutils'

# 3.1b — LocalGateway: filesystem round-trip + single-use HMAC tokens (R-P8) + path safety.
#
# Public interface mirrors the AWS Gateway (presign_upload, presign_download, head, delete)
# so frontend code is identical across environments. Adds dev/test-only helpers used by the
# local-storage Roda routes (3.12): write, read, verify_upload_token, verify_download_token.
# Token TTLs per R-P8: 15 min upload, 5 min download. Both single-use within their TTL.

# Top-level helpers — kept here so each describe stays under Metrics/BlockLength.
module LocalGatewaySpecSupport
  TEST_SIGNING_KEY = 'test-signing-key-for-local-gateway-spec'
  TEST_BASE_URL = 'http://localhost:9292'

  def build_gateway
    @tmp_root = Dir.mktmpdir('tyto-local-storage-')
    Tyto::FileStorage::LocalGateway.new(
      root: @tmp_root,
      signing_key: TEST_SIGNING_KEY,
      base_url: TEST_BASE_URL
    )
  end

  def cleanup_tmp_root
    FileUtils.remove_entry(@tmp_root) if @tmp_root && Dir.exist?(@tmp_root)
  end

  def upload_token_from(payload)
    payload[:fields][:token] || payload[:fields]['token']
  end
end

describe 'Tyto::FileStorage::LocalGateway #presign_upload' do
  include LocalGatewaySpecSupport

  before { @gateway = build_gateway }
  after  { cleanup_tmp_root }

  let(:result) { @gateway.presign_upload(key: '1/2/3.pdf', allowed_extensions: ['.pdf']) }

  it 'returns Success carrying upload_url and fields' do
    _(result.success?).must_equal true
    _(result.value![:upload_url]).must_be_kind_of String
    _(result.value![:fields]).must_be_kind_of Hash
  end

  it 'targets the configured base_url and the local-storage upload path' do
    url = result.value![:upload_url]
    _(url).must_include LocalGatewaySpecSupport::TEST_BASE_URL
    _(url).must_include '_local_storage/upload'
  end

  it 'embeds a single-use signed token (in fields or query string)' do
    payload = result.value!
    has_token = upload_token_from(payload) || payload[:upload_url].include?('token=')
    _(has_token).wont_be_nil
  end
end

describe 'Tyto::FileStorage::LocalGateway #presign_download' do
  include LocalGatewaySpecSupport

  before { @gateway = build_gateway }
  after  { cleanup_tmp_root }

  it 'returns Success with a download_url even before bytes are stored' do
    result = @gateway.presign_download(key: '1/2/3.pdf')
    _(result.success?).must_equal true
    _(result.value![:download_url]).must_include '_local_storage/download'
  end

  it 'mints a distinct token on each call (single-use semantics)' do
    a = @gateway.presign_download(key: '1/2/3.pdf').value![:download_url]
    b = @gateway.presign_download(key: '1/2/3.pdf').value![:download_url]
    _(a).wont_equal b
  end
end

describe 'Tyto::FileStorage::LocalGateway filesystem round-trip' do
  include LocalGatewaySpecSupport

  before { @gateway = build_gateway }
  after  { cleanup_tmp_root }

  let(:key) { '1/2/3.pdf' }
  let(:body) { 'hello bytes' }

  it 'head returns Failure for a missing key' do
    _(@gateway.head(key:).failure?).must_equal true
  end

  it 'write makes head succeed and read return the bytes' do
    @gateway.write(key:, body:)
    _(@gateway.head(key:).success?).must_equal true
    _(@gateway.read(key:).value!).must_equal body
  end

  it 'delete removes the stored bytes' do
    @gateway.write(key:, body:)
    @gateway.delete(key:)
    _(@gateway.head(key:).failure?).must_equal true
  end

  it 'delete returns Failure when the key is missing' do
    _(@gateway.delete(key:).failure?).must_equal true
  end
end

describe 'Tyto::FileStorage::LocalGateway upload token validation (R-P8)' do
  include LocalGatewaySpecSupport

  before { @gateway = build_gateway }
  after  { cleanup_tmp_root }

  let(:key) { '1/2/3.pdf' }
  let(:fresh_token) do
    upload_token_from(@gateway.presign_upload(key:, allowed_extensions: ['.pdf']).value!)
  end

  it 'a freshly minted upload token verifies once' do
    _(@gateway.verify_upload_token(token: fresh_token, key:).success?).must_equal true
  end

  it 'a replayed upload token is rejected on second use' do
    @gateway.verify_upload_token(token: fresh_token, key:)
    _(@gateway.verify_upload_token(token: fresh_token, key:).failure?).must_equal true
  end

  it 'a tampered or unknown token is rejected' do
    _(@gateway.verify_upload_token(token: 'not-a-real-token', key:).failure?).must_equal true
  end

  it 'an expired upload token is rejected' do
    token = nil
    Time.stub :now, Time.now - (16 * 60) do
      token = upload_token_from(@gateway.presign_upload(key:, allowed_extensions: ['.pdf']).value!)
    end
    _(@gateway.verify_upload_token(token:, key:).failure?).must_equal true
  end
end

describe 'Tyto::FileStorage::LocalGateway cross-op token rejection (R-P8)' do
  include LocalGatewaySpecSupport

  before { @gateway = build_gateway }
  after  { cleanup_tmp_root }

  let(:key) { '1/2/3.pdf' }

  it 'an upload token cannot be used as a download token' do
    token = upload_token_from(@gateway.presign_upload(key:, allowed_extensions: ['.pdf']).value!)
    _(@gateway.verify_download_token(token:, key:).failure?).must_equal true
  end

  it 'a token minted for one key cannot be used to access another' do
    token = upload_token_from(@gateway.presign_upload(key: '1/2/3.pdf', allowed_extensions: ['.pdf']).value!)
    _(@gateway.verify_upload_token(token:, key: '9/9/9.pdf').failure?).must_equal true
  end
end

# Path safety used to live on LocalGateway as a private validate_key! that
# every public method called. With the StorageKey value object, the
# guarantee is on the type — there is no way to construct a StorageKey
# wrapping `..` or an absolute path, so the gateway's public methods can
# trust their `key:` argument. See `storage_key_spec.rb` for the
# construction-time tests.
