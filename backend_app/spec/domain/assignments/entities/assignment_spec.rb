# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Domain::Assignments::Entities::Assignment' do
  let(:now) { Time.now }
  let(:one_day) { 24 * 60 * 60 }

  let(:valid_attributes) do
    {
      id: 1,
      course_id: 10,
      event_id: nil,
      title: 'Homework 1: Data Wrangling',
      description: 'Use R to clean and transform the dataset.',
      status: 'draft',
      due_at: now + 7 * one_day,
      allow_late_resubmit: false,
      created_at: now - one_day,
      updated_at: now
    }
  end

  describe 'creation' do
    it 'creates a valid assignment with all attributes' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes)

      _(assignment.id).must_equal 1
      _(assignment.course_id).must_equal 10
      _(assignment.event_id).must_be_nil
      _(assignment.title).must_equal 'Homework 1: Data Wrangling'
      _(assignment.description).must_equal 'Use R to clean and transform the dataset.'
      _(assignment.status).must_equal 'draft'
      _(assignment.due_at).must_be_close_to(now + 7 * one_day, 1)
      _(assignment.allow_late_resubmit).must_equal false
    end

    it 'creates an assignment with minimal attributes' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: nil,
        course_id: 10,
        title: 'Minimal Assignment',
        created_at: nil,
        updated_at: nil
      )

      _(assignment.id).must_be_nil
      _(assignment.title).must_equal 'Minimal Assignment'
      _(assignment.description).must_be_nil
      _(assignment.event_id).must_be_nil
      _(assignment.due_at).must_be_nil
    end

    it 'defaults status to draft' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: nil,
        course_id: 10,
        title: 'Default Status',
        created_at: nil,
        updated_at: nil
      )

      _(assignment.status).must_equal 'draft'
    end

    it 'defaults allow_late_resubmit to false' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: nil,
        course_id: 10,
        title: 'Default Late Resubmit',
        created_at: nil,
        updated_at: nil
      )

      _(assignment.allow_late_resubmit).must_equal false
    end

    it 'accepts event_id when provided' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(
        valid_attributes.merge(event_id: 5)
      )

      _(assignment.event_id).must_equal 5
    end
  end

  describe 'constraint enforcement' do
    it 'rejects empty title' do
      _ { Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes.merge(title: '')) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects title over 200 characters' do
      _ { Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes.merge(title: 'A' * 201)) }
        .must_raise Dry::Struct::Error
    end

    it 'accepts title at exactly 200 characters' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(
        valid_attributes.merge(title: 'A' * 200)
      )

      _(assignment.title.length).must_equal 200
    end

    it 'requires course_id' do
      _ { Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes.merge(course_id: nil)) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects invalid status' do
      _ { Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes.merge(status: 'archived')) }
        .must_raise Dry::Struct::Error
    end

    it 'accepts all valid statuses' do
      %w[draft published disabled].each do |status|
        assignment = Tyto::Domain::Assignments::Entities::Assignment.new(
          valid_attributes.merge(status: status)
        )
        _(assignment.status).must_equal status
      end
    end
  end

  describe 'immutability' do
    it 'updates via new() preserving other attributes' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes)
      updated = assignment.new(title: 'Updated Title')

      _(updated.title).must_equal 'Updated Title'
      _(updated.id).must_equal assignment.id
      _(updated.course_id).must_equal assignment.course_id
      _(updated.status).must_equal assignment.status
    end

    it 'enforces constraints on update' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes)

      _ { assignment.new(title: '') }.must_raise Dry::Struct::Error
    end

    it 'can transition status' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes)
      published = assignment.new(status: 'published')

      _(published.status).must_equal 'published'
      _(published.title).must_equal assignment.title
    end
  end

  describe 'submission requirements collection' do
    it 'defaults submission_requirements to nil (not loaded)' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes)

      _(assignment.submission_requirements).must_be_nil
    end

    it 'reports requirements not loaded when nil' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes)

      _(assignment.requirements_loaded?).must_equal false
    end

    it 'reports requirements loaded when present' do
      requirements = Tyto::Domain::Assignments::Values::SubmissionRequirements.from([])
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(
        valid_attributes.merge(submission_requirements: requirements)
      )

      _(assignment.requirements_loaded?).must_equal true
    end
  end

  describe 'linked event' do
    it 'defaults linked_event to nil (not loaded or no event)' do
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(valid_attributes)

      _(assignment.linked_event).must_be_nil
    end

    it 'accepts a LinkedEvent value object' do
      linked = Tyto::Domain::Assignments::Values::LinkedEvent.new(
        id: 3, name: 'Week 1 Lecture', start_at: now, end_at: now + one_day
      )
      assignment = Tyto::Domain::Assignments::Entities::Assignment.new(
        valid_attributes.merge(event_id: 3, linked_event: linked)
      )

      _(assignment.linked_event).must_be_kind_of Tyto::Domain::Assignments::Values::LinkedEvent
      _(assignment.linked_event.name).must_equal 'Week 1 Lecture'
    end
  end
end
