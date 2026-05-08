# frozen_string_literal: true

require_relative '../../spec_helper'

# Generic constraints encoding for the file_storage Mapper.
#
# The Mapper takes a target S3 key and emits the AWS presigned-POST policy
# fields that the Gateway will hand to bucket.presigned_post. Per R-P1 we
# need POST (not PUT) so the size cap is enforced server-side by S3 via the
# signed policy doc; per R-P7 the size cap pulls from the single
# Tyto::FileStorage::MAX_SIZE_BYTES constant.
#
# Extension enforcement is delivered upstream of the policy doc — see the
# class-level comment on Mapper for the rationale.

def length_condition(conditions)
  conditions.find { |c| c.is_a?(Array) && c.first == 'content-length-range' }
end

def key_condition(conditions)
  conditions.find { |c| c.is_a?(Hash) && c.key?('key') }
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

  it 'emits exactly two conditions — extension enforcement happens upstream' do
    _(result[:conditions].length).must_equal 2
  end

  it 'accepts allowed_extensions for API symmetry but does not encode it' do
    with_ext  = mapper.policy_conditions(key: '1/2/3.pdf', allowed_extensions: ['.pdf'])
    no_ext    = mapper.policy_conditions(key: '1/2/3.pdf', allowed_extensions: nil)
    empty_ext = mapper.policy_conditions(key: '1/2/3.pdf', allowed_extensions: [])

    _(with_ext).must_equal(no_ext)
    _(with_ext).must_equal(empty_ext)
  end
end

# Mapper used to validate `key` itself; that responsibility now lives on
# Tyto::FileStorage::StorageKey, which raises on construction from invalid
# input. Mapper trusts its caller to pass a StorageKey.
# See `storage_key_spec.rb` for the construction-time validation.
