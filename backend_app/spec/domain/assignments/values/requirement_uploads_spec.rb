# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Domain::Assignments::Values::RequirementUploads do
  let(:now) { Time.now }

  let(:file_upload) do
    Tyto::Domain::Assignments::Entities::RequirementUpload.new(
      id: 1, submission_id: 10, requirement_id: 5,
      content: '10/5/3.Rmd', filename: 'homework1.Rmd',
      content_type: 'text/x-r-markdown', file_size: 2048,
      created_at: now, updated_at: now
    )
  end

  let(:url_upload) do
    Tyto::Domain::Assignments::Entities::RequirementUpload.new(
      id: 2, submission_id: 10, requirement_id: 6,
      content: '10/6/3.url', filename: nil,
      content_type: nil, file_size: nil,
      created_at: now, updated_at: now
    )
  end

  let(:pdf_upload) do
    Tyto::Domain::Assignments::Entities::RequirementUpload.new(
      id: 3, submission_id: 10, requirement_id: 7,
      content: '10/7/3.pdf', filename: 'report.pdf',
      content_type: 'application/pdf', file_size: 5120,
      created_at: now, updated_at: now
    )
  end

  describe '.from' do
    it 'creates collection from array of uploads' do
      collection = Tyto::Domain::Assignments::Values::RequirementUploads.from(
        [file_upload, url_upload]
      )

      _(collection.count).must_equal 2
    end

    it 'handles empty array' do
      collection = Tyto::Domain::Assignments::Values::RequirementUploads.from([])

      _(collection.count).must_equal 0
      _(collection.empty?).must_equal true
    end

    it 'handles nil as empty collection' do
      collection = Tyto::Domain::Assignments::Values::RequirementUploads.from(nil)

      _(collection.count).must_equal 0
      _(collection.empty?).must_equal true
    end
  end

  describe '#find_by_requirement' do
    let(:collection) do
      Tyto::Domain::Assignments::Values::RequirementUploads.from(
        [file_upload, url_upload, pdf_upload]
      )
    end

    it 'finds upload by requirement ID' do
      found = collection.find_by_requirement(6)

      _(found.content).must_equal '10/6/3.url'
    end

    it 'returns nil when requirement not found' do
      _(collection.find_by_requirement(999)).must_be_nil
    end
  end

  describe '#to_a' do
    it 'returns array of uploads' do
      collection = Tyto::Domain::Assignments::Values::RequirementUploads.from(
        [file_upload, url_upload]
      )

      arr = collection.to_a
      _(arr).must_be_kind_of Array
      _(arr.length).must_equal 2
      _(arr.first.content).must_equal '10/5/3.Rmd'
    end
  end

  describe 'iteration' do
    it 'supports each' do
      collection = Tyto::Domain::Assignments::Values::RequirementUploads.from(
        [file_upload, url_upload]
      )
      contents = []
      collection.each { |u| contents << u.content }

      _(contents).must_equal ['10/5/3.Rmd', '10/6/3.url']
    end

    it 'supports map via Enumerable' do
      collection = Tyto::Domain::Assignments::Values::RequirementUploads.from(
        [file_upload, url_upload]
      )

      req_ids = collection.map(&:requirement_id)
      _(req_ids).must_equal [5, 6]
    end
  end

  describe '#any?' do
    it 'returns true when collection has uploads' do
      collection = Tyto::Domain::Assignments::Values::RequirementUploads.from([file_upload])

      _(collection.any?).must_equal true
    end

    it 'returns false when collection is empty' do
      collection = Tyto::Domain::Assignments::Values::RequirementUploads.from([])

      _(collection.any?).must_equal false
    end
  end

  describe '#empty?' do
    it 'returns true when collection is empty' do
      collection = Tyto::Domain::Assignments::Values::RequirementUploads.from([])

      _(collection.empty?).must_equal true
    end

    it 'returns false when collection has uploads' do
      collection = Tyto::Domain::Assignments::Values::RequirementUploads.from([file_upload])

      _(collection.empty?).must_equal false
    end
  end

  describe 'type safety' do
    it 'rejects non-RequirementUpload objects' do
      _ { Tyto::Domain::Assignments::Values::RequirementUploads.from(['not an upload']) }
        .must_raise Dry::Struct::Error
    end
  end
end
