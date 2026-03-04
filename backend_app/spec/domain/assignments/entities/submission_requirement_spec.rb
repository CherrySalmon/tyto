# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Domain::Assignments::Entities::SubmissionRequirement' do
  let(:now) { Time.now }

  let(:valid_file_attributes) do
    {
      id: 1,
      assignment_id: 10,
      submission_format: 'file',
      description: 'R Markdown source file',
      allowed_types: 'Rmd,qmd',
      sort_order: 0,
      created_at: now,
      updated_at: now
    }
  end

  let(:valid_url_attributes) do
    {
      id: 2,
      assignment_id: 10,
      submission_format: 'url',
      description: 'GitHub repository link',
      allowed_types: nil,
      sort_order: 1,
      created_at: now,
      updated_at: now
    }
  end

  describe 'creation' do
    it 'creates a valid file-type requirement' do
      req = Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(valid_file_attributes)

      _(req.id).must_equal 1
      _(req.assignment_id).must_equal 10
      _(req.submission_format).must_equal 'file'
      _(req.description).must_equal 'R Markdown source file'
      _(req.allowed_types).must_equal 'Rmd,qmd'
      _(req.sort_order).must_equal 0
    end

    it 'creates a valid url-type requirement' do
      req = Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(valid_url_attributes)

      _(req.submission_format).must_equal 'url'
      _(req.description).must_equal 'GitHub repository link'
      _(req.allowed_types).must_be_nil
    end

    it 'creates a requirement with minimal attributes' do
      req = Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
        id: nil,
        assignment_id: 10,
        submission_format: 'file',
        description: 'Upload your solution',
        allowed_types: nil,
        sort_order: 0,
        created_at: nil,
        updated_at: nil
      )

      _(req.id).must_be_nil
      _(req.description).must_equal 'Upload your solution'
    end
  end

  describe 'constraint enforcement' do
    it 'requires assignment_id' do
      _ { Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
        valid_file_attributes.merge(assignment_id: nil)
      ) }.must_raise Dry::Struct::Error
    end

    it 'rejects invalid submission_format' do
      _ { Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
        valid_file_attributes.merge(submission_format: 'text')
      ) }.must_raise Dry::Struct::Error
    end

    it 'accepts file submission_format' do
      req = Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(valid_file_attributes)
      _(req.submission_format).must_equal 'file'
    end

    it 'accepts url submission_format' do
      req = Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(valid_url_attributes)
      _(req.submission_format).must_equal 'url'
    end

    it 'requires description' do
      _ { Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
        valid_file_attributes.merge(description: nil)
      ) }.must_raise Dry::Struct::Error
    end

    it 'requires sort_order' do
      _ { Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
        valid_file_attributes.merge(sort_order: nil)
      ) }.must_raise Dry::Struct::Error
    end
  end

  describe 'immutability' do
    it 'updates via new() preserving other attributes' do
      req = Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(valid_file_attributes)
      updated = req.new(description: 'Updated description')

      _(updated.description).must_equal 'Updated description'
      _(updated.id).must_equal req.id
      _(updated.assignment_id).must_equal req.assignment_id
      _(updated.submission_format).must_equal req.submission_format
    end

    it 'enforces constraints on update' do
      req = Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(valid_file_attributes)

      _ { req.new(submission_format: 'invalid') }.must_raise Dry::Struct::Error
    end
  end
end
