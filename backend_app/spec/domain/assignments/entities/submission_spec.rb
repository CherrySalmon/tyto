# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Domain::Assignments::Entities::Submission' do
  let(:now) { Time.now }
  let(:one_day) { 24 * 60 * 60 }

  let(:valid_attributes) do
    {
      id: 1,
      assignment_id: 10,
      account_id: 5,
      submitted_at: now,
      created_at: now - one_day,
      updated_at: now
    }
  end

  describe 'creation' do
    it 'creates a valid submission with all attributes' do
      submission = Tyto::Domain::Assignments::Entities::Submission.new(valid_attributes)

      _(submission.id).must_equal 1
      _(submission.assignment_id).must_equal 10
      _(submission.account_id).must_equal 5
      _(submission.submitted_at).must_be_close_to(now, 1)
    end

    it 'creates a submission with nil id (before persistence)' do
      submission = Tyto::Domain::Assignments::Entities::Submission.new(
        valid_attributes.merge(id: nil)
      )

      _(submission.id).must_be_nil
      _(submission.assignment_id).must_equal 10
      _(submission.account_id).must_equal 5
    end
  end

  describe 'constraint enforcement' do
    it 'requires assignment_id' do
      _ { Tyto::Domain::Assignments::Entities::Submission.new(valid_attributes.merge(assignment_id: nil)) }
        .must_raise Dry::Struct::Error
    end

    it 'requires account_id' do
      _ { Tyto::Domain::Assignments::Entities::Submission.new(valid_attributes.merge(account_id: nil)) }
        .must_raise Dry::Struct::Error
    end

    it 'requires submitted_at' do
      _ { Tyto::Domain::Assignments::Entities::Submission.new(valid_attributes.merge(submitted_at: nil)) }
        .must_raise Dry::Struct::Error
    end
  end

  describe 'immutability' do
    it 'updates via new() preserving other attributes' do
      submission = Tyto::Domain::Assignments::Entities::Submission.new(valid_attributes)
      updated_time = now + one_day
      updated = submission.new(submitted_at: updated_time)

      _(updated.submitted_at).must_be_close_to(updated_time, 1)
      _(updated.id).must_equal submission.id
      _(updated.assignment_id).must_equal submission.assignment_id
      _(updated.account_id).must_equal submission.account_id
    end
  end

  describe 'requirement uploads collection' do
    it 'defaults requirement_uploads to nil (not loaded)' do
      submission = Tyto::Domain::Assignments::Entities::Submission.new(valid_attributes)

      _(submission.requirement_uploads).must_be_nil
    end

    it 'reports uploads not loaded when nil' do
      submission = Tyto::Domain::Assignments::Entities::Submission.new(valid_attributes)

      _(submission.uploads_loaded?).must_equal false
    end

    it 'reports uploads loaded when present' do
      uploads = Tyto::Domain::Assignments::Values::RequirementUploads.from([])
      submission = Tyto::Domain::Assignments::Entities::Submission.new(
        valid_attributes.merge(requirement_uploads: uploads)
      )

      _(submission.uploads_loaded?).must_equal true
    end
  end

  describe 'submitter' do
    it 'defaults submitter to nil (not loaded)' do
      submission = Tyto::Domain::Assignments::Entities::Submission.new(valid_attributes)

      _(submission.submitter).must_be_nil
    end

    it 'accepts a Submitter value object' do
      submitter = Tyto::Domain::Assignments::Values::Submitter.new(
        account_id: 5, name: 'Ada Lovelace', email: 'ada@example.com'
      )
      submission = Tyto::Domain::Assignments::Entities::Submission.new(
        valid_attributes.merge(submitter: submitter)
      )

      _(submission.submitter).must_be_kind_of Tyto::Domain::Assignments::Values::Submitter
      _(submission.submitter.name).must_equal 'Ada Lovelace'
      _(submission.submitter.email).must_equal 'ada@example.com'
    end
  end
end
