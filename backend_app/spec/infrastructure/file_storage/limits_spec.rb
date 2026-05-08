# frozen_string_literal: true

require_relative '../../spec_helper'

# 3.1f — `Tyto::FileStorage::MAX_SIZE_BYTES` is the single source of truth for the
# per-file upload cap (R-P7). Referenced by:
#   - Mapper's presigned-POST policy doc (content-length-range)
#   - CreateSubmission's Slice-2 file-size validator (currently a magic 10_485_760)
#   - The frontend (via /api/config/file_storage_limits or build-time env var, TBD in 3.18)
#
# This trivial spec exists so the constant is grounded by a test rather than
# scattered as a magic number, per the TDD gate.

describe 'Tyto::FileStorage::MAX_SIZE_BYTES' do
  it 'is defined' do
    _(defined?(Tyto::FileStorage::MAX_SIZE_BYTES)).wont_be_nil
  end

  it 'equals 10 * 1024 * 1024 bytes (10 MiB) per Q8 + R-P7' do
    _(Tyto::FileStorage::MAX_SIZE_BYTES).must_equal 10 * 1024 * 1024
  end

  it 'is an Integer (so Ranges and arithmetic work without coercion)' do
    _(Tyto::FileStorage::MAX_SIZE_BYTES).must_be_kind_of Integer
  end
end
