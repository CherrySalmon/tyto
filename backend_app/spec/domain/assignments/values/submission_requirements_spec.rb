# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Domain::Assignments::Values::SubmissionRequirements do
  let(:now) { Time.now }

  let(:file_req) do
    Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
      id: 1, assignment_id: 10, submission_format: 'file',
      description: 'R Markdown source file', allowed_types: '.Rmd,.qmd',
      sort_order: 0, created_at: now, updated_at: now
    )
  end

  let(:url_req) do
    Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
      id: 2, assignment_id: 10, submission_format: 'url',
      description: 'GitHub repository link', allowed_types: nil,
      sort_order: 1, created_at: now, updated_at: now
    )
  end

  let(:pdf_req) do
    Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
      id: 3, assignment_id: 10, submission_format: 'file',
      description: 'PDF report', allowed_types: '.pdf',
      sort_order: 2, created_at: now, updated_at: now
    )
  end

  describe '.from' do
    it 'creates collection from array of requirements' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from(
        [file_req, url_req]
      )

      _(collection.count).must_equal 2
    end

    it 'handles empty array' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from([])

      _(collection.count).must_equal 0
      _(collection.empty?).must_equal true
    end

    it 'handles nil as empty collection' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from(nil)

      _(collection.count).must_equal 0
      _(collection.empty?).must_equal true
    end
  end

  describe '#find' do
    let(:collection) do
      Tyto::Domain::Assignments::Values::SubmissionRequirements.from(
        [file_req, url_req, pdf_req]
      )
    end

    it 'finds requirement by ID' do
      found = collection.find(2)

      _(found.description).must_equal 'GitHub repository link'
    end

    it 'returns nil when requirement not found' do
      _(collection.find(999)).must_be_nil
    end
  end

  describe '#count' do
    it 'returns number of requirements' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from(
        [file_req, url_req]
      )

      _(collection.count).must_equal 2
    end

    it 'returns 0 for empty collection' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from([])

      _(collection.count).must_equal 0
    end
  end

  describe '#to_a' do
    it 'returns array of requirements' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from(
        [file_req, url_req]
      )

      arr = collection.to_a
      _(arr).must_be_kind_of Array
      _(arr.length).must_equal 2
      _(arr.first.description).must_equal 'R Markdown source file'
    end
  end

  describe 'iteration' do
    it 'supports each' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from(
        [file_req, url_req]
      )
      descriptions = []
      collection.each { |r| descriptions << r.description }

      _(descriptions).must_equal ['R Markdown source file', 'GitHub repository link']
    end

    it 'supports map via Enumerable' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from(
        [file_req, url_req]
      )

      formats = collection.map(&:submission_format)
      _(formats).must_equal %w[file url]
    end
  end

  describe '#any?' do
    it 'returns true when collection has requirements' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from([file_req])

      _(collection.any?).must_equal true
    end

    it 'returns false when collection is empty' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from([])

      _(collection.any?).must_equal false
    end
  end

  describe '#empty?' do
    it 'returns true when collection is empty' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from([])

      _(collection.empty?).must_equal true
    end

    it 'returns false when collection has requirements' do
      collection = Tyto::Domain::Assignments::Values::SubmissionRequirements.from([file_req])

      _(collection.empty?).must_equal false
    end
  end

  describe 'type safety' do
    it 'rejects non-SubmissionRequirement objects' do
      _ { Tyto::Domain::Assignments::Values::SubmissionRequirements.from(['not a requirement']) }
        .must_raise Dry::Struct::Error
    end
  end
end
