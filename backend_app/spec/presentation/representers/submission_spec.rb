# frozen_string_literal: true

require_relative '../../spec_helper'

# Specs for Tyto::Representer::RequirementUploadRepr and Tyto::Representer::Submission
# focused on the `download_url` field. The representer emits `download_url` as a path
# to the backend download route — the backend authorizes and 302-redirects to a
# freshly-minted presigned GET on click. Render-time presigned URLs are intentionally
# avoided (long-open staff views would silently expire them).
#
# Contract surfaced by these tests:
#   Representer::Submission.new(submission).to_hash(
#     user_options: {
#       course_id:,                # external — not on the entity
#       assignment_id:,            # already on submission, kept here so the per-upload
#                                  #   representer doesn't have to reach back to its parent
#       requirements_by_id:,       # { requirement_id => SubmissionRequirement } —
#                                  #   for file-vs-url discrimination per upload
#       can_download:              # authorization decision made upstream by the route
#     }
#   )

describe 'Tyto::Representer::RequirementUploadRepr#download_url' do
  def build_upload(id: 17, submission_id: 7, requirement_id: 11,
                   content: 's3-key/whatever',
                   filename: 'paper.pdf', content_type: 'application/pdf', file_size: 1024)
    Tyto::Domain::Assignments::Entities::RequirementUpload.new(
      id:, submission_id:, requirement_id:, content:,
      filename:, content_type:, file_size:,
      created_at: nil, updated_at: nil
    )
  end

  def build_requirement(id: 11, submission_format: 'file', allowed_types: '.pdf,.rmd')
    Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
      id:, assignment_id: 42,
      submission_format:,
      description: 'Required submission',
      allowed_types:,
      sort_order: 1,
      created_at: nil, updated_at: nil
    )
  end

  def serialize(upload, user_options:)
    Tyto::Representer::RequirementUploadRepr.new(upload).to_hash(user_options:)
  end

  it 'emits a backend route path for file-type entries when permitted' do
    upload = build_upload(id: 17, submission_id: 7, requirement_id: 11)
    requirement = build_requirement(id: 11, submission_format: 'file')

    hash = serialize(upload, user_options: {
                       course_id: 5,
                       assignment_id: 42,
                       requirements_by_id: { 11 => requirement },
                       can_download: true
                     })

    _(hash['download_url']).must_equal(
      '/api/course/5/assignments/42/submissions/7/uploads/17/download'
    )
  end

  it 'reflects the upload-specific ids — different upload, different URL' do
    upload = build_upload(id: 99, submission_id: 23, requirement_id: 11)
    requirement = build_requirement(id: 11, submission_format: 'file')

    hash = serialize(upload, user_options: {
                       course_id: 5,
                       assignment_id: 42,
                       requirements_by_id: { 11 => requirement },
                       can_download: true
                     })

    _(hash['download_url']).must_equal(
      '/api/course/5/assignments/42/submissions/23/uploads/99/download'
    )
  end

  it 'omits download_url for url-type entries even when permitted' do
    upload = build_upload(id: 17, submission_id: 7, requirement_id: 11,
                          content: 'https://github.com/me/repo',
                          filename: nil, content_type: nil, file_size: nil)
    requirement = build_requirement(id: 11, submission_format: 'url', allowed_types: nil)

    hash = serialize(upload, user_options: {
                       course_id: 5,
                       assignment_id: 42,
                       requirements_by_id: { 11 => requirement },
                       can_download: true
                     })

    _(hash['download_url']).must_be_nil
  end

  it 'omits download_url for file-type entries when requestor cannot download' do
    upload = build_upload(id: 17, submission_id: 7, requirement_id: 11)
    requirement = build_requirement(id: 11, submission_format: 'file')

    hash = serialize(upload, user_options: {
                       course_id: 5,
                       assignment_id: 42,
                       requirements_by_id: { 11 => requirement },
                       can_download: false
                     })

    _(hash['download_url']).must_be_nil
  end

  it 'omits download_url when the requirement is missing from the lookup' do
    # Defensive: a stale lookup or a misuse should not produce a broken URL.
    upload = build_upload(id: 17, submission_id: 7, requirement_id: 11)

    hash = serialize(upload, user_options: {
                       course_id: 5,
                       assignment_id: 42,
                       requirements_by_id: {},
                       can_download: true
                     })

    _(hash['download_url']).must_be_nil
  end

  it 'omits download_url when no user_options context is provided' do
    upload = build_upload(id: 17, submission_id: 7, requirement_id: 11)

    hash = Tyto::Representer::RequirementUploadRepr.new(upload).to_hash

    _(hash['download_url']).must_be_nil
  end

  it 'still emits content and base fields regardless of download_url state' do
    # Regression guard — the existing Slice 2 contract (content, filename, etc.)
    # is unchanged by adding download_url.
    upload = build_upload(id: 17, content: 'some-key.pdf', filename: 'paper.pdf')

    hash = Tyto::Representer::RequirementUploadRepr.new(upload).to_hash

    _(hash['id']).must_equal 17
    _(hash['content']).must_equal 'some-key.pdf'
    _(hash['filename']).must_equal 'paper.pdf'
  end
end

describe 'Tyto::Representer::Submission user_options threading' do
  def build_upload(id:, requirement_id:, submission_format:)
    content = submission_format == 'file' ? "key-#{id}.pdf" : 'https://example.org'
    filename = submission_format == 'file' ? "file-#{id}.pdf" : nil
    Tyto::Domain::Assignments::Entities::RequirementUpload.new(
      id:, submission_id: 7, requirement_id:, content:,
      filename:, content_type: nil, file_size: nil,
      created_at: nil, updated_at: nil
    )
  end

  def build_requirement(id:, submission_format:)
    Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
      id:, assignment_id: 42, submission_format:,
      description: 'r', allowed_types: nil, sort_order: 1,
      created_at: nil, updated_at: nil
    )
  end

  def build_submission(uploads:)
    Tyto::Domain::Assignments::Entities::Submission.new(
      id: 7, assignment_id: 42, account_id: 99,
      submitted_at: Time.utc(2026, 5, 1),
      created_at: nil, updated_at: nil,
      requirement_uploads: Tyto::Domain::Assignments::Values::RequirementUploads.from(uploads),
      submitter: nil
    )
  end

  it 'threads user_options to nested upload representers so each one builds its URL' do
    file_upload = build_upload(id: 100, requirement_id: 11, submission_format: 'file')
    url_upload  = build_upload(id: 101, requirement_id: 12, submission_format: 'url')

    submission = build_submission(uploads: [file_upload, url_upload])
    requirements_by_id = {
      11 => build_requirement(id: 11, submission_format: 'file'),
      12 => build_requirement(id: 12, submission_format: 'url')
    }

    hash = Tyto::Representer::Submission.new(submission).to_hash(user_options: {
                                                                   course_id: 5,
                                                                   assignment_id: 42,
                                                                   requirements_by_id:,
                                                                   can_download: true
                                                                 })

    file_hash = hash['requirement_uploads'].find { |u| u['id'] == 100 }
    url_hash  = hash['requirement_uploads'].find { |u| u['id'] == 101 }

    _(file_hash['download_url']).must_equal(
      '/api/course/5/assignments/42/submissions/7/uploads/100/download'
    )
    _(url_hash['download_url']).must_be_nil
  end
end
