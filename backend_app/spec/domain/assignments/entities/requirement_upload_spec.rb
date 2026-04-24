# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Domain::Assignments::Entities::RequirementUpload' do
  let(:now) { Time.now }

  let(:valid_file_attributes) do
    {
      id: 1,
      submission_id: 10,
      requirement_id: 5,
      content: '10/5/3.Rmd',
      filename: 'homework1.Rmd',
      content_type: 'text/x-r-markdown',
      file_size: 2048,
      created_at: now,
      updated_at: now
    }
  end

  let(:valid_url_attributes) do
    {
      id: 2,
      submission_id: 10,
      requirement_id: 6,
      content: '10/6/3.url',
      filename: nil,
      content_type: nil,
      file_size: nil,
      created_at: now,
      updated_at: now
    }
  end

  describe 'creation' do
    it 'creates a valid file upload with all attributes' do
      upload = Tyto::Domain::Assignments::Entities::RequirementUpload.new(valid_file_attributes)

      _(upload.id).must_equal 1
      _(upload.submission_id).must_equal 10
      _(upload.requirement_id).must_equal 5
      _(upload.content).must_equal '10/5/3.Rmd'
      _(upload.filename).must_equal 'homework1.Rmd'
      _(upload.content_type).must_equal 'text/x-r-markdown'
      _(upload.file_size).must_equal 2048
    end

    it 'creates a valid URL upload (no filename, content_type, or file_size)' do
      upload = Tyto::Domain::Assignments::Entities::RequirementUpload.new(valid_url_attributes)

      _(upload.id).must_equal 2
      _(upload.content).must_equal '10/6/3.url'
      _(upload.filename).must_be_nil
      _(upload.content_type).must_be_nil
      _(upload.file_size).must_be_nil
    end

    it 'creates with nil id (before persistence)' do
      upload = Tyto::Domain::Assignments::Entities::RequirementUpload.new(
        valid_file_attributes.merge(id: nil)
      )

      _(upload.id).must_be_nil
      _(upload.submission_id).must_equal 10
    end

    it 'defaults optional fields to nil' do
      upload = Tyto::Domain::Assignments::Entities::RequirementUpload.new(
        id: nil,
        submission_id: 10,
        requirement_id: 5,
        content: '10/5/3.pdf',
        created_at: nil,
        updated_at: nil
      )

      _(upload.filename).must_be_nil
      _(upload.content_type).must_be_nil
      _(upload.file_size).must_be_nil
    end
  end

  describe 'constraint enforcement' do
    it 'requires submission_id' do
      _ { Tyto::Domain::Assignments::Entities::RequirementUpload.new(valid_file_attributes.merge(submission_id: nil)) }
        .must_raise Dry::Struct::Error
    end

    it 'requires requirement_id' do
      _ { Tyto::Domain::Assignments::Entities::RequirementUpload.new(valid_file_attributes.merge(requirement_id: nil)) }
        .must_raise Dry::Struct::Error
    end

    it 'requires content' do
      _ { Tyto::Domain::Assignments::Entities::RequirementUpload.new(valid_file_attributes.merge(content: nil)) }
        .must_raise Dry::Struct::Error
    end
  end

  describe 'immutability' do
    it 'updates via new() preserving other attributes' do
      upload = Tyto::Domain::Assignments::Entities::RequirementUpload.new(valid_file_attributes)
      updated = upload.new(content: '10/5/3.qmd', filename: 'homework1.qmd')

      _(updated.content).must_equal '10/5/3.qmd'
      _(updated.filename).must_equal 'homework1.qmd'
      _(updated.id).must_equal upload.id
      _(updated.submission_id).must_equal upload.submission_id
      _(updated.requirement_id).must_equal upload.requirement_id
    end
  end
end
