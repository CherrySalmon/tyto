# frozen_string_literal: true

require_relative '../../spec_helper'

# 3.1e — SubmissionMapper: submission-specific S3 key construction.
#
# Per R2: key = "<course_id>/<assignment_id>/<requirement_id>/<account_id>.<extension>".
# No submission_id (avoids chicken-and-egg with persistence). course_id at the
# top groups everything for a course so an operator can browse a course's
# uploads by S3 prefix; requirement_id before account_id groups all student
# uploads per requirement for batch download.
#
# Used by IssueUploadGrants to BUILD keys from authenticated context, and by
# CreateSubmission to RECONSTRUCT keys for HEAD verification per R-P2 — same
# method, single source of truth, so the reconstructed key is bit-identical to
# the one the presign step issued.
#
# URL-type requirements never go through this mapper: URL `content` stays as a
# raw string (Q3 un-unify). Mapper rejects submission_format != 'file' eagerly.

# Shared args — kept top-level so each describe stays under Metrics/BlockLength.
module SubmissionMapperSpecSupport
  VALID_ARGS = {
    course_id: 10,
    assignment_id: 1,
    requirement_id: 2,
    account_id: 3,
    filename: 'analysis.Rmd',
    submission_format: 'file'
  }.freeze
end

describe 'Tyto::FileStorage::SubmissionMapper.build_key happy path' do
  it 'builds a key in the form <course_id>/<assignment_id>/<requirement_id>/<account_id>.<ext>' do
    key = Tyto::FileStorage::SubmissionMapper.build_key(**SubmissionMapperSpecSupport::VALID_ARGS)
    _(key).must_be_kind_of Tyto::FileStorage::StorageKey
    _(key.to_s).must_equal '10/1/2/3.rmd'
  end

  it 'lowercases the extension' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(filename: 'paper.PDF')
    _(Tyto::FileStorage::SubmissionMapper.build_key(**args).to_s).must_equal '10/1/2/3.pdf'
  end

  it 'uses only the final segment of a multi-dot filename' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(filename: 'archive.tar.gz')
    _(Tyto::FileStorage::SubmissionMapper.build_key(**args).to_s).must_equal '10/1/2/3.gz'
  end
end

describe 'Tyto::FileStorage::SubmissionMapper.build_key submission_format validation' do
  it 'rejects submission_format = "url" (URLs do not get S3 keys)' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(submission_format: 'url')
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end

  it 'rejects an unknown submission_format' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(submission_format: 'something-else')
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end
end

describe 'Tyto::FileStorage::SubmissionMapper.build_key id validation' do
  it 'rejects nil course_id' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(course_id: nil)
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end

  it 'rejects non-positive course_id' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(course_id: 0)
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end

  it 'rejects nil assignment_id' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(assignment_id: nil)
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end

  it 'rejects non-positive assignment_id' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(assignment_id: 0)
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end

  it 'rejects nil requirement_id' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(requirement_id: nil)
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end

  it 'rejects nil account_id' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(account_id: nil)
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end

  it 'rejects negative ids' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(account_id: -1)
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end
end

describe 'Tyto::FileStorage::SubmissionMapper.build_key filename validation' do
  it 'rejects nil filename' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(filename: nil)
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end

  it 'rejects empty filename' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(filename: '')
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end

  it 'rejects filename without an extension' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(filename: 'README')
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end

  it 'rejects filename whose extension is empty (trailing dot)' do
    args = SubmissionMapperSpecSupport::VALID_ARGS.merge(filename: 'foo.')
    _(-> { Tyto::FileStorage::SubmissionMapper.build_key(**args) }).must_raise ArgumentError
  end
end
