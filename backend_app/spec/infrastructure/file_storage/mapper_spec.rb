# frozen_string_literal: true

require_relative '../../spec_helper'

# 3.1a — Generic constraints encoding for the file_storage Mapper.
#
# The Mapper takes a target S3 key + optional allowed-extension list and emits the
# AWS presigned-POST policy fields that the Gateway will hand to bucket.presigned_post.
# Per R-P1 we need POST (not PUT) so the size cap is enforced server-side by S3 via
# the signed policy doc; per R-P7 the size cap pulls from a single Tyto::FileStorage::MAX_SIZE_BYTES.

# Policy-condition lookups, kept top-level so each describe stays under Metrics/BlockLength.
def length_condition(conditions)
  conditions.find { |c| c.is_a?(Array) && c.first == 'content-length-range' }
end

def key_condition(conditions)
  conditions.find { |c| c.is_a?(Hash) && c.key?('key') }
end

def extension_condition(conditions)
  conditions.find do |c|
    c.is_a?(Array) && (c[1] == '$Content-Type' || (c.first == 'starts-with' && c[1] == '$key'))
  end
end

describe 'Tyto::FileStorage::Mapper #policy_conditions output shape' do
  let(:mapper) { Tyto::FileStorage::Mapper.new }
  let(:result) { mapper.policy_conditions(key: '1/2/3.pdf', allowed_extensions: ['.pdf', '.rmd']) }

  it 'returns a Hash carrying a :conditions array' do
    _(result).must_be_kind_of Hash
    _(result[:conditions]).must_be_kind_of Array
    _(result[:conditions]).wont_be_empty
  end

  it 'encodes content-length-range from Tyto::FileStorage::MAX_SIZE_BYTES (R-P7)' do
    cond = length_condition(result[:conditions])
    _(cond).wont_be_nil
    _(cond[1]).must_equal 1
    _(cond[2]).must_equal Tyto::FileStorage::MAX_SIZE_BYTES
  end

  it 'pins the exact S3 key with an equality condition' do
    cond = key_condition(result[:conditions])
    _(cond).wont_be_nil
    _(cond['key']).must_equal '1/2/3.pdf'
  end
end

describe 'Tyto::FileStorage::Mapper #policy_conditions extension constraint' do
  let(:mapper) { Tyto::FileStorage::Mapper.new }
  let(:key) { '1/2/3.pdf' }

  it 'encodes allowed extensions via $Content-Type or starts-with $key' do
    result = mapper.policy_conditions(key:, allowed_extensions: ['.pdf', '.rmd'])
    _(extension_condition(result[:conditions])).wont_be_nil
  end

  it 'omits any extension constraint when allowed_extensions is empty' do
    result = mapper.policy_conditions(key:, allowed_extensions: [])
    _(extension_condition(result[:conditions])).must_be_nil
  end

  it 'omits any extension constraint when allowed_extensions is nil' do
    result = mapper.policy_conditions(key:, allowed_extensions: nil)
    _(extension_condition(result[:conditions])).must_be_nil
  end

  it 'still emits content-length-range when allowed_extensions is empty' do
    result = mapper.policy_conditions(key:, allowed_extensions: [])
    cond = length_condition(result[:conditions])
    _(cond).wont_be_nil
    _(cond[2]).must_equal Tyto::FileStorage::MAX_SIZE_BYTES
  end

  it 'normalises extensions with or without leading dots' do
    result = mapper.policy_conditions(key: '1/2/3.rmd', allowed_extensions: ['rmd', '.pdf'])
    _(extension_condition(result[:conditions])).wont_be_nil
  end
end

# Mapper used to validate `key` itself; that responsibility now lives on
# Tyto::FileStorage::StorageKey, which raises on construction from invalid
# input. Mapper trusts its caller to pass a StorageKey.
# See `storage_key_spec.rb` for the construction-time validation.
