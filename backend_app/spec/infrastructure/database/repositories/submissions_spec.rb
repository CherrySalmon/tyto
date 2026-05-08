# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Repository::Submissions' do
  let(:repository) { Tyto::Repository::Submissions.new }
  let(:now) { Time.now }
  let(:one_day) { 24 * 60 * 60 }

  # Shared test data setup
  let(:orm_course) { Tyto::Course.create(name: 'Test Course') }
  let(:orm_account) { Tyto::Account.create(email: 'student@example.com') }
  let(:another_account) { Tyto::Account.create(email: 'another@example.com') }
  let(:orm_assignment) do
    Tyto::Assignment.create(
      course_id: orm_course.id,
      title: 'Homework 1',
      status: 'published',
      allow_late_resubmit: false
    )
  end
  let(:another_assignment) do
    Tyto::Assignment.create(
      course_id: orm_course.id,
      title: 'Homework 2',
      status: 'published',
      allow_late_resubmit: false
    )
  end
  let(:file_requirement) do
    Tyto::SubmissionRequirement.create(
      assignment_id: orm_assignment.id,
      submission_format: 'file',
      description: 'R Markdown source',
      allowed_types: 'Rmd,qmd',
      sort_order: 0
    )
  end
  let(:url_requirement) do
    Tyto::SubmissionRequirement.create(
      assignment_id: orm_assignment.id,
      submission_format: 'url',
      description: 'GitHub repo link',
      sort_order: 1
    )
  end

  describe '#create' do
    it 'persists a new submission and returns entity with ID' do
      entity = Tyto::Domain::Assignments::Entities::Submission.new(
        id: nil,
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result).must_be_instance_of Tyto::Domain::Assignments::Entities::Submission
      _(result.id).wont_be_nil
      _(result.assignment_id).must_equal orm_assignment.id
      _(result.account_id).must_equal orm_account.id
      _(result.submitted_at).wont_be_nil
      _(result.created_at).wont_be_nil
      _(result.updated_at).wont_be_nil
    end

    it 'returns submission with entries not loaded' do
      entity = Tyto::Domain::Assignments::Entities::Submission.new(
        id: nil,
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result.uploads_loaded?).must_equal false
    end
  end

  describe '#create_with_entries' do
    it 'persists submission and its entries' do
      entity = Tyto::Domain::Assignments::Entities::Submission.new(
        id: nil,
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now,
        created_at: nil,
        updated_at: nil
      )

      # Force lazy lets
      file_requirement
      url_requirement

      entries = [
        Tyto::Domain::Assignments::Entities::RequirementUpload.new(
          id: nil, submission_id: 0, requirement_id: file_requirement.id,
          content: "#{orm_assignment.id}/#{file_requirement.id}/#{orm_account.id}.Rmd",
          filename: 'homework1.Rmd', content_type: 'text/x-r-markdown', file_size: 2048,
          created_at: nil, updated_at: nil
        ),
        Tyto::Domain::Assignments::Entities::RequirementUpload.new(
          id: nil, submission_id: 0, requirement_id: url_requirement.id,
          content: "#{orm_assignment.id}/#{url_requirement.id}/#{orm_account.id}.url",
          filename: nil, content_type: nil, file_size: nil,
          created_at: nil, updated_at: nil
        )
      ]

      result = repository.create_with_entries(entity, entries)

      _(result.id).wont_be_nil
      _(result.uploads_loaded?).must_equal true
      _(result.requirement_uploads.count).must_equal 2

      # Verify entries have correct submission_id
      result.requirement_uploads.each do |upload|
        _(upload.submission_id).must_equal result.id
        _(upload.id).wont_be_nil
      end
    end

    it 'returns submission with empty entries when none provided' do
      entity = Tyto::Domain::Assignments::Entities::Submission.new(
        id: nil,
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create_with_entries(entity, [])

      _(result.uploads_loaded?).must_equal true
      _(result.requirement_uploads.empty?).must_equal true
    end
  end

  describe '#find_id' do
    it 'returns domain entity for existing submission' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )

      result = repository.find_id(orm_submission.id)

      _(result).must_be_instance_of Tyto::Domain::Assignments::Entities::Submission
      _(result.id).must_equal orm_submission.id
      _(result.assignment_id).must_equal orm_assignment.id
      _(result.account_id).must_equal orm_account.id
    end

    it 'returns submission with entries not loaded (nil)' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )

      result = repository.find_id(orm_submission.id)

      _(result.requirement_uploads).must_be_nil
      _(result.uploads_loaded?).must_equal false
    end

    it 'returns nil for non-existent submission' do
      result = repository.find_id(999_999)

      _(result).must_be_nil
    end
  end

  describe '#find_with_entries' do
    it 'returns submission with entries loaded' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )
      Tyto::SubmissionEntry.create(
        submission_id: orm_submission.id,
        requirement_id: file_requirement.id,
        content: "#{orm_assignment.id}/#{file_requirement.id}/#{orm_account.id}.Rmd",
        filename: 'homework1.Rmd',
        content_type: 'text/x-r-markdown',
        file_size: 2048
      )
      Tyto::SubmissionEntry.create(
        submission_id: orm_submission.id,
        requirement_id: url_requirement.id,
        content: "#{orm_assignment.id}/#{url_requirement.id}/#{orm_account.id}.url"
      )

      result = repository.find_with_entries(orm_submission.id)

      _(result.uploads_loaded?).must_equal true
      _(result.requirement_uploads.count).must_equal 2
    end

    it 'returns empty collection for submission with no entries' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )

      result = repository.find_with_entries(orm_submission.id)

      _(result.uploads_loaded?).must_equal true
      _(result.requirement_uploads.empty?).must_equal true
    end

    it 'returns nil for non-existent submission' do
      _(repository.find_with_entries(999_999)).must_be_nil
    end
  end

  describe '#find_by_account_assignment' do
    it 'returns submission for a student and assignment' do
      Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )

      result = repository.find_by_account_assignment(orm_account.id, orm_assignment.id)

      _(result).must_be_instance_of Tyto::Domain::Assignments::Entities::Submission
      _(result.account_id).must_equal orm_account.id
      _(result.assignment_id).must_equal orm_assignment.id
    end

    it 'returns nil when no submission exists' do
      result = repository.find_by_account_assignment(orm_account.id, orm_assignment.id)

      _(result).must_be_nil
    end

    it 'does not return other students submissions' do
      Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: another_account.id,
        submitted_at: now
      )

      result = repository.find_by_account_assignment(orm_account.id, orm_assignment.id)

      _(result).must_be_nil
    end
  end

  describe '#find_by_account_assignment_with_entries' do
    it 'returns submission with entries for a student and assignment' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )
      Tyto::SubmissionEntry.create(
        submission_id: orm_submission.id,
        requirement_id: file_requirement.id,
        content: "#{orm_assignment.id}/#{file_requirement.id}/#{orm_account.id}.Rmd",
        filename: 'homework1.Rmd',
        content_type: 'text/x-r-markdown',
        file_size: 2048
      )

      result = repository.find_by_account_assignment_with_entries(orm_account.id, orm_assignment.id)

      _(result.uploads_loaded?).must_equal true
      _(result.requirement_uploads.count).must_equal 1
      _(result.requirement_uploads.first.filename).must_equal 'homework1.Rmd'
    end

    it 'returns nil when no submission exists' do
      result = repository.find_by_account_assignment_with_entries(orm_account.id, orm_assignment.id)

      _(result).must_be_nil
    end
  end

  describe '#find_by_assignment' do
    it 'returns all submissions for an assignment' do
      Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )
      Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: another_account.id,
        submitted_at: now + 60
      )

      result = repository.find_by_assignment(orm_assignment.id)

      _(result.length).must_equal 2
    end

    it 'returns empty array when no submissions exist' do
      result = repository.find_by_assignment(orm_assignment.id)

      _(result).must_equal []
    end

    it 'does not return submissions from other assignments' do
      Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )
      Tyto::Submission.create(
        assignment_id: another_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )

      result = repository.find_by_assignment(orm_assignment.id)

      _(result.length).must_equal 1
      _(result.first.assignment_id).must_equal orm_assignment.id
    end

    it 'returns submissions without entries loaded' do
      Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )

      result = repository.find_by_assignment(orm_assignment.id)

      result.each do |submission|
        _(submission.uploads_loaded?).must_equal false
      end
    end
  end

  describe '#find_by_assignment_with_entries' do
    it 'returns submissions with entries loaded' do
      sub1 = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )
      Tyto::SubmissionEntry.create(
        submission_id: sub1.id,
        requirement_id: file_requirement.id,
        content: "#{orm_assignment.id}/#{file_requirement.id}/#{orm_account.id}.Rmd",
        filename: 'homework1.Rmd',
        content_type: 'text/x-r-markdown',
        file_size: 2048
      )

      result = repository.find_by_assignment_with_entries(orm_assignment.id)

      _(result.length).must_equal 1
      _(result.first.uploads_loaded?).must_equal true
      _(result.first.requirement_uploads.count).must_equal 1
    end
  end

  describe '#update' do
    it 'updates submitted_at and returns updated entity' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )

      entity = repository.find_id(orm_submission.id)
      new_time = now + one_day
      updated_entity = entity.new(submitted_at: new_time)

      result = repository.update(updated_entity)

      _(result.submitted_at).must_be_close_to(new_time, 1)
      _(result.id).must_equal orm_submission.id
    end

    it 'raises error for non-existent submission' do
      entity = Tyto::Domain::Assignments::Entities::Submission.new(
        id: 999_999,
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now,
        created_at: nil,
        updated_at: nil
      )

      _ { repository.update(entity) }.must_raise RuntimeError
    end
  end

  describe '#upsert_entries' do
    it 'inserts new entries for a submission' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )

      # Force lazy lets
      file_requirement
      url_requirement

      entries = [
        Tyto::Domain::Assignments::Entities::RequirementUpload.new(
          id: nil, submission_id: orm_submission.id, requirement_id: file_requirement.id,
          content: "#{orm_assignment.id}/#{file_requirement.id}/#{orm_account.id}.Rmd",
          filename: 'homework1.Rmd', content_type: 'text/x-r-markdown', file_size: 2048,
          created_at: nil, updated_at: nil
        )
      ]

      result = repository.upsert_entries(orm_submission.id, entries)

      _(result.uploads_loaded?).must_equal true
      _(result.requirement_uploads.count).must_equal 1
      _(result.requirement_uploads.first.filename).must_equal 'homework1.Rmd'
    end

    it 'updates existing entry matched by requirement_id' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )
      Tyto::SubmissionEntry.create(
        submission_id: orm_submission.id,
        requirement_id: file_requirement.id,
        content: "#{orm_assignment.id}/#{file_requirement.id}/#{orm_account.id}.Rmd",
        filename: 'old_file.Rmd',
        content_type: 'text/x-r-markdown',
        file_size: 1024
      )

      updated_entries = [
        Tyto::Domain::Assignments::Entities::RequirementUpload.new(
          id: nil, submission_id: orm_submission.id, requirement_id: file_requirement.id,
          content: "#{orm_assignment.id}/#{file_requirement.id}/#{orm_account.id}.qmd",
          filename: 'new_file.qmd', content_type: 'text/x-quarto', file_size: 4096,
          created_at: nil, updated_at: nil
        )
      ]

      result = repository.upsert_entries(orm_submission.id, updated_entries)

      _(result.requirement_uploads.count).must_equal 1
      upload = result.requirement_uploads.first
      _(upload.filename).must_equal 'new_file.qmd'
      _(upload.file_size).must_equal 4096

      # Verify no duplicate entries created
      _(Tyto::SubmissionEntry.where(submission_id: orm_submission.id).count).must_equal 1
    end

    it 'preserves entries for other requirements during upsert' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )
      Tyto::SubmissionEntry.create(
        submission_id: orm_submission.id,
        requirement_id: file_requirement.id,
        content: "#{orm_assignment.id}/#{file_requirement.id}/#{orm_account.id}.Rmd",
        filename: 'existing.Rmd',
        content_type: 'text/x-r-markdown',
        file_size: 1024
      )

      # Upsert only the URL requirement entry
      new_entries = [
        Tyto::Domain::Assignments::Entities::RequirementUpload.new(
          id: nil, submission_id: orm_submission.id, requirement_id: url_requirement.id,
          content: "#{orm_assignment.id}/#{url_requirement.id}/#{orm_account.id}.url",
          filename: nil, content_type: nil, file_size: nil,
          created_at: nil, updated_at: nil
        )
      ]

      result = repository.upsert_entries(orm_submission.id, new_entries)

      _(result.requirement_uploads.count).must_equal 2
      _(Tyto::SubmissionEntry.where(submission_id: orm_submission.id).count).must_equal 2
    end

    it 'raises error for non-existent submission' do
      entries = [
        Tyto::Domain::Assignments::Entities::RequirementUpload.new(
          id: nil, submission_id: 999_999, requirement_id: file_requirement.id,
          content: 'fake/key.Rmd', filename: 'file.Rmd',
          content_type: 'text/plain', file_size: 100,
          created_at: nil, updated_at: nil
        )
      ]

      _ { repository.upsert_entries(999_999, entries) }.must_raise RuntimeError
    end
  end

  describe '#find_by_assignment_full' do
    it 'returns each submission with entries AND submitter loaded' do
      Tyto::Submission.create(
        assignment_id: orm_assignment.id, account_id: orm_account.id, submitted_at: now
      )
      Tyto::Submission.create(
        assignment_id: orm_assignment.id, account_id: another_account.id, submitted_at: now + 60
      )

      result = repository.find_by_assignment_full(orm_assignment.id)

      _(result.length).must_equal 2
      result.each do |submission|
        _(submission.uploads_loaded?).must_equal true
        _(submission.submitter).must_be_kind_of Tyto::Domain::Assignments::Values::Submitter
        _(submission.submitter.account_id).must_equal submission.account_id
        _(submission.submitter.email).wont_be_nil
      end
    end

    it 'returns empty array when no submissions exist' do
      _(repository.find_by_assignment_full(orm_assignment.id)).must_equal []
    end

    it 'still populates submitter when the account has no name' do
      nameless = Tyto::Account.create(email: 'noname@example.com')
      Tyto::Submission.create(
        assignment_id: orm_assignment.id, account_id: nameless.id, submitted_at: now
      )

      result = repository.find_by_assignment_full(orm_assignment.id)

      _(result.length).must_equal 1
      _(result.first.submitter.name).must_be_nil
      _(result.first.submitter.email).must_equal 'noname@example.com'
    end
  end

  describe '#any_for_assignment?' do
    it 'returns true when at least one submission exists for the assignment' do
      Tyto::Submission.create(
        assignment_id: orm_assignment.id, account_id: orm_account.id, submitted_at: now
      )

      _(repository.any_for_assignment?(orm_assignment.id)).must_equal true
    end

    it 'returns false when no submission exists for the assignment' do
      _(repository.any_for_assignment?(orm_assignment.id)).must_equal false
    end

    it 'returns false when submissions exist only for a different assignment' do
      Tyto::Submission.create(
        assignment_id: another_assignment.id, account_id: orm_account.id, submitted_at: now
      )

      _(repository.any_for_assignment?(orm_assignment.id)).must_equal false
    end
  end

  describe '#assignment_ids_with_submissions' do
    it 'returns the subset of given assignment IDs that have at least one submission' do
      Tyto::Submission.create(
        assignment_id: orm_assignment.id, account_id: orm_account.id, submitted_at: now
      )

      result = repository.assignment_ids_with_submissions([orm_assignment.id, another_assignment.id])

      _(result).must_include orm_assignment.id
      _(result).wont_include another_assignment.id
    end

    it 'returns empty collection when no submissions exist for any of the given IDs' do
      result = repository.assignment_ids_with_submissions([orm_assignment.id, another_assignment.id])

      _(result.to_a).must_be_empty
    end

    it 'returns empty collection when given an empty list' do
      _(repository.assignment_ids_with_submissions([]).to_a).must_be_empty
    end

    it 'returns unique IDs even when multiple submissions exist per assignment' do
      Tyto::Submission.create(
        assignment_id: orm_assignment.id, account_id: orm_account.id, submitted_at: now
      )
      Tyto::Submission.create(
        assignment_id: orm_assignment.id, account_id: another_account.id, submitted_at: now + 60
      )

      result = repository.assignment_ids_with_submissions([orm_assignment.id])

      _(result.to_a).must_equal [orm_assignment.id]
    end
  end

  describe '#delete' do
    it 'deletes existing submission and returns true' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )

      result = repository.delete(orm_submission.id)

      _(result).must_equal true
      _(repository.find_id(orm_submission.id)).must_be_nil
    end

    it 'returns false for non-existent submission' do
      result = repository.delete(999_999)

      _(result).must_equal false
    end

    it 'cascades delete to submission entries' do
      orm_submission = Tyto::Submission.create(
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now
      )
      Tyto::SubmissionEntry.create(
        submission_id: orm_submission.id,
        requirement_id: file_requirement.id,
        content: "#{orm_assignment.id}/#{file_requirement.id}/#{orm_account.id}.Rmd",
        filename: 'homework1.Rmd',
        content_type: 'text/x-r-markdown',
        file_size: 2048
      )

      repository.delete(orm_submission.id)

      _(Tyto::SubmissionEntry.where(submission_id: orm_submission.id).count).must_equal 0
    end
  end

  describe 'round-trip' do
    it 'maintains data integrity through create -> find -> upsert -> find cycle' do
      # Force lazy lets
      file_requirement
      url_requirement

      # Create
      entity = Tyto::Domain::Assignments::Entities::Submission.new(
        id: nil,
        assignment_id: orm_assignment.id,
        account_id: orm_account.id,
        submitted_at: now,
        created_at: nil,
        updated_at: nil
      )
      created = repository.create(entity)
      _(created.id).wont_be_nil

      # Find
      found = repository.find_with_entries(created.id)
      _(found.assignment_id).must_equal orm_assignment.id
      _(found.uploads_loaded?).must_equal true
      _(found.requirement_uploads.empty?).must_equal true

      # Upsert entries
      entries = [
        Tyto::Domain::Assignments::Entities::RequirementUpload.new(
          id: nil, submission_id: created.id, requirement_id: file_requirement.id,
          content: "#{orm_assignment.id}/#{file_requirement.id}/#{orm_account.id}.Rmd",
          filename: 'homework1.Rmd', content_type: 'text/x-r-markdown', file_size: 2048,
          created_at: nil, updated_at: nil
        )
      ]
      upserted = repository.upsert_entries(created.id, entries)
      _(upserted.requirement_uploads.count).must_equal 1

      # Find again to verify persistence
      final = repository.find_with_entries(created.id)
      _(final.requirement_uploads.count).must_equal 1
      _(final.requirement_uploads.first.filename).must_equal 'homework1.Rmd'
    end
  end
end
