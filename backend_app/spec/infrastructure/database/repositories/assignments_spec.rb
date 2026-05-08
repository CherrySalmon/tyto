# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Repository::Assignments' do
  let(:repository) { Tyto::Repository::Assignments.new }
  let(:now) { Time.now }
  let(:one_day) { 24 * 60 * 60 }

  # Shared test data setup
  let(:orm_course) { Tyto::Course.create(name: 'Test Course') }
  let(:orm_location) { Tyto::Location.create(course_id: orm_course.id, name: 'Room A') }
  let(:orm_event) do
    Tyto::Event.create(
      course_id: orm_course.id,
      location_id: orm_location.id,
      name: 'Lecture 1',
      start_at: now,
      end_at: now + 3600
    )
  end

  describe '#create' do
    it 'persists a new assignment and returns entity with ID' do
      entity = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: nil,
        course_id: orm_course.id,
        title: 'Homework 1',
        description: 'Do the thing.',
        due_at: now + 7 * one_day,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result).must_be_instance_of Tyto::Domain::Assignments::Entities::Assignment
      _(result.id).wont_be_nil
      _(result.title).must_equal 'Homework 1'
      _(result.description).must_equal 'Do the thing.'
      _(result.status).must_equal 'draft'
      _(result.allow_late_resubmit).must_equal false
      _(result.created_at).wont_be_nil
      _(result.updated_at).wont_be_nil
    end

    it 'persists assignment with event_id' do
      entity = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: nil,
        course_id: orm_course.id,
        event_id: orm_event.id,
        title: 'Event-Linked Assignment',
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result.event_id).must_equal orm_event.id
    end

    it 'persists assignment with minimal attributes' do
      entity = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: nil,
        course_id: orm_course.id,
        title: 'Minimal',
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result.id).wont_be_nil
      _(result.title).must_equal 'Minimal'
      _(result.description).must_be_nil
      _(result.event_id).must_be_nil
      _(result.due_at).must_be_nil
      _(result.status).must_equal 'draft'
    end
  end

  describe '#create_with_requirements' do
    it 'persists assignment and its requirements' do
      entity = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: nil,
        course_id: orm_course.id,
        title: 'HW with Requirements',
        created_at: nil,
        updated_at: nil
      )

      requirements = [
        Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
          id: nil, assignment_id: 0, submission_format: 'file',
          description: 'R Markdown source', allowed_types: 'Rmd,qmd',
          sort_order: 0, created_at: nil, updated_at: nil
        ),
        Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
          id: nil, assignment_id: 0, submission_format: 'url',
          description: 'GitHub repo link', allowed_types: nil,
          sort_order: 1, created_at: nil, updated_at: nil
        )
      ]

      result = repository.create_with_requirements(entity, requirements)

      _(result.id).wont_be_nil
      _(result.requirements_loaded?).must_equal true
      _(result.submission_requirements.count).must_equal 2
      _(result.submission_requirements.map(&:description)).must_include 'R Markdown source'
      _(result.submission_requirements.map(&:description)).must_include 'GitHub repo link'

      # Verify requirements have correct assignment_id
      result.submission_requirements.each do |req|
        _(req.assignment_id).must_equal result.id
        _(req.id).wont_be_nil
      end
    end

    it 'returns assignment with empty requirements when none provided' do
      entity = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: nil,
        course_id: orm_course.id,
        title: 'No Requirements',
        created_at: nil,
        updated_at: nil
      )

      result = repository.create_with_requirements(entity, [])

      _(result.requirements_loaded?).must_equal true
      _(result.submission_requirements.empty?).must_equal true
    end
  end

  describe '#find_id' do
    it 'returns domain entity for existing assignment' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'Find Me',
        description: 'Description here',
        status: 'draft',
        allow_late_resubmit: false
      )

      result = repository.find_id(orm_assignment.id)

      _(result).must_be_instance_of Tyto::Domain::Assignments::Entities::Assignment
      _(result.id).must_equal orm_assignment.id
      _(result.title).must_equal 'Find Me'
      _(result.description).must_equal 'Description here'
    end

    it 'returns assignment with requirements not loaded (nil)' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'No Children',
        status: 'draft',
        allow_late_resubmit: false
      )

      result = repository.find_id(orm_assignment.id)

      _(result.submission_requirements).must_be_nil
      _(result.requirements_loaded?).must_equal false
    end

    it 'returns nil for non-existent assignment' do
      result = repository.find_id(999_999)

      _(result).must_be_nil
    end
  end

  describe '#find_with_requirements' do
    it 'returns assignment with requirements loaded' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'With Requirements',
        status: 'published',
        allow_late_resubmit: false
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: orm_assignment.id,
        submission_format: 'file',
        description: 'R Markdown source',
        allowed_types: 'Rmd,qmd',
        sort_order: 0
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: orm_assignment.id,
        submission_format: 'url',
        description: 'GitHub link',
        sort_order: 1
      )

      result = repository.find_with_requirements(orm_assignment.id)

      _(result.requirements_loaded?).must_equal true
      _(result.submission_requirements.count).must_equal 2
      _(result.submission_requirements.map(&:description)).must_include 'R Markdown source'
      _(result.submission_requirements.map(&:description)).must_include 'GitHub link'
    end

    it 'returns requirements ordered by sort_order' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'Ordered Requirements',
        status: 'draft',
        allow_late_resubmit: false
      )
      # Create in reverse order to test sorting
      Tyto::SubmissionRequirement.create(
        assignment_id: orm_assignment.id,
        submission_format: 'url',
        description: 'Second',
        sort_order: 1
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: orm_assignment.id,
        submission_format: 'file',
        description: 'First',
        allowed_types: 'pdf',
        sort_order: 0
      )

      result = repository.find_with_requirements(orm_assignment.id)

      descriptions = result.submission_requirements.map(&:description)
      _(descriptions).must_equal %w[First Second]
    end

    it 'returns empty collection for assignment with no requirements' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'No Requirements',
        status: 'draft',
        allow_late_resubmit: false
      )

      result = repository.find_with_requirements(orm_assignment.id)

      _(result.requirements_loaded?).must_equal true
      _(result.submission_requirements.empty?).must_equal true
    end

    it 'returns nil for non-existent assignment' do
      _(repository.find_with_requirements(999_999)).must_be_nil
    end
  end

  describe '#find_full' do
    it 'returns assignment with requirements AND linked event loaded when event_id is set' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        event_id: orm_event.id,
        title: 'Tied To Event',
        status: 'published',
        allow_late_resubmit: false
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: orm_assignment.id,
        submission_format: 'url',
        description: 'Link',
        sort_order: 0
      )

      result = repository.find_full(orm_assignment.id)

      _(result.requirements_loaded?).must_equal true
      _(result.submission_requirements.count).must_equal 1
      _(result.linked_event).must_be_kind_of Tyto::Domain::Assignments::Values::LinkedEvent
      _(result.linked_event.id).must_equal orm_event.id
      _(result.linked_event.name).must_equal 'Lecture 1'
      _(result.linked_event.start_at).must_be_close_to(now, 1)
      _(result.linked_event.end_at).must_be_close_to(now + 3600, 1)
    end

    it 'returns assignment with nil linked_event when event_id is nil' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'No Event',
        status: 'draft',
        allow_late_resubmit: false
      )

      result = repository.find_full(orm_assignment.id)

      _(result.requirements_loaded?).must_equal true
      _(result.linked_event).must_be_nil
    end

    it 'returns assignment with nil linked_event when the referenced event was deleted' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        event_id: orm_event.id,
        title: 'Orphaned',
        status: 'draft',
        allow_late_resubmit: false
      )
      orm_event.destroy # nullify the FK (on_delete: :set_null)
      orm_assignment.refresh

      result = repository.find_full(orm_assignment.id)

      _(result.linked_event).must_be_nil
    end

    it 'returns nil for non-existent assignment' do
      _(repository.find_full(999_999)).must_be_nil
    end
  end

  describe '#find_by_course' do
    it 'returns all assignments for a course' do
      Tyto::Assignment.create(course_id: orm_course.id, title: 'HW 1', status: 'draft', allow_late_resubmit: false)
      Tyto::Assignment.create(course_id: orm_course.id, title: 'HW 2', status: 'published', allow_late_resubmit: false)
      Tyto::Assignment.create(course_id: orm_course.id, title: 'HW 3', status: 'disabled', allow_late_resubmit: false)

      result = repository.find_by_course(orm_course.id)

      _(result.length).must_equal 3
      _(result.map(&:title)).must_include 'HW 1'
      _(result.map(&:title)).must_include 'HW 2'
      _(result.map(&:title)).must_include 'HW 3'
    end

    it 'returns empty array when no assignments exist' do
      result = repository.find_by_course(orm_course.id)

      _(result).must_equal []
    end

    it 'does not return assignments from other courses' do
      other_course = Tyto::Course.create(name: 'Other Course')
      Tyto::Assignment.create(course_id: orm_course.id, title: 'Mine', status: 'draft', allow_late_resubmit: false)
      Tyto::Assignment.create(course_id: other_course.id, title: 'Theirs', status: 'draft', allow_late_resubmit: false)

      result = repository.find_by_course(orm_course.id)

      _(result.length).must_equal 1
      _(result.first.title).must_equal 'Mine'
    end

    it 'returns assignments without requirements loaded' do
      Tyto::Assignment.create(course_id: orm_course.id, title: 'HW 1', status: 'draft', allow_late_resubmit: false)

      result = repository.find_by_course(orm_course.id)

      result.each do |assignment|
        _(assignment.requirements_loaded?).must_equal false
      end
    end
  end

  describe '#find_by_course_and_status' do
    it 'returns only assignments with matching status' do
      Tyto::Assignment.create(course_id: orm_course.id, title: 'Draft', status: 'draft', allow_late_resubmit: false)
      Tyto::Assignment.create(course_id: orm_course.id, title: 'Published 1', status: 'published', allow_late_resubmit: false)
      Tyto::Assignment.create(course_id: orm_course.id, title: 'Published 2', status: 'published', allow_late_resubmit: false)
      Tyto::Assignment.create(course_id: orm_course.id, title: 'Disabled', status: 'disabled', allow_late_resubmit: false)

      result = repository.find_by_course_and_status(orm_course.id, 'published')

      _(result.length).must_equal 2
      result.each { |a| _(a.status).must_equal 'published' }
    end

    it 'returns empty array when no assignments match status' do
      Tyto::Assignment.create(course_id: orm_course.id, title: 'Draft', status: 'draft', allow_late_resubmit: false)

      result = repository.find_by_course_and_status(orm_course.id, 'published')

      _(result).must_equal []
    end
  end

  describe '#find_by_course_with_requirements' do
    it 'returns assignments with requirements loaded' do
      a1 = Tyto::Assignment.create(course_id: orm_course.id, title: 'HW 1', status: 'draft', allow_late_resubmit: false)
      Tyto::SubmissionRequirement.create(
        assignment_id: a1.id, submission_format: 'file',
        description: 'Source code', sort_order: 0
      )
      a2 = Tyto::Assignment.create(course_id: orm_course.id, title: 'HW 2', status: 'published', allow_late_resubmit: false)
      Tyto::SubmissionRequirement.create(
        assignment_id: a2.id, submission_format: 'url',
        description: 'Repo link', sort_order: 0
      )

      result = repository.find_by_course_with_requirements(orm_course.id)

      _(result.length).must_equal 2
      result.each do |assignment|
        _(assignment.requirements_loaded?).must_equal true
        _(assignment.submission_requirements.count).must_be :>=, 1
      end
    end

    it 'returns empty requirements for assignments that have none' do
      Tyto::Assignment.create(course_id: orm_course.id, title: 'No Reqs', status: 'draft', allow_late_resubmit: false)

      result = repository.find_by_course_with_requirements(orm_course.id)

      _(result.first.requirements_loaded?).must_equal true
      _(result.first.submission_requirements.empty?).must_equal true
    end
  end

  describe '#update' do
    it 'updates existing assignment and returns updated entity' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'Original',
        description: 'Old description',
        status: 'draft',
        allow_late_resubmit: false
      )

      entity = repository.find_id(orm_assignment.id)
      updated_entity = entity.new(title: 'Updated', description: 'New description')

      result = repository.update(updated_entity)

      _(result.title).must_equal 'Updated'
      _(result.description).must_equal 'New description'
      _(result.id).must_equal orm_assignment.id

      # Verify persistence
      reloaded = repository.find_id(orm_assignment.id)
      _(reloaded.title).must_equal 'Updated'
    end

    it 'updates status (publish transition)' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'To Publish',
        status: 'draft',
        allow_late_resubmit: false
      )

      entity = repository.find_id(orm_assignment.id)
      published = entity.new(status: 'published')

      result = repository.update(published)

      _(result.status).must_equal 'published'
    end

    it 'raises error for non-existent assignment' do
      entity = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: 999_999,
        course_id: orm_course.id,
        title: 'Ghost',
        status: 'draft',
        created_at: nil,
        updated_at: nil
      )

      _ { repository.update(entity) }.must_raise RuntimeError
    end
  end

  describe '#update_with_requirements' do
    it 'updates assignment metadata and replaces requirements' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'Original',
        status: 'draft',
        allow_late_resubmit: false
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: orm_assignment.id,
        submission_format: 'file',
        description: 'Old requirement',
        sort_order: 0
      )

      entity = repository.find_id(orm_assignment.id)
      updated_entity = entity.new(title: 'Updated Title')

      new_requirements = [
        Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
          id: nil, assignment_id: orm_assignment.id, submission_format: 'url',
          description: 'New URL requirement', allowed_types: nil,
          sort_order: 0, created_at: nil, updated_at: nil
        ),
        Tyto::Domain::Assignments::Entities::SubmissionRequirement.new(
          id: nil, assignment_id: orm_assignment.id, submission_format: 'file',
          description: 'New file requirement', allowed_types: 'pdf,docx',
          sort_order: 1, created_at: nil, updated_at: nil
        )
      ]

      result = repository.update_with_requirements(updated_entity, new_requirements)

      _(result.title).must_equal 'Updated Title'
      _(result.requirements_loaded?).must_equal true
      _(result.submission_requirements.count).must_equal 2
      _(result.submission_requirements.map(&:description)).must_include 'New URL requirement'
      _(result.submission_requirements.map(&:description)).must_include 'New file requirement'
      _(result.submission_requirements.map(&:description)).wont_include 'Old requirement'
    end

    it 'clears all requirements when empty array provided' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'Has Reqs',
        status: 'draft',
        allow_late_resubmit: false
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: orm_assignment.id,
        submission_format: 'file',
        description: 'To be removed',
        sort_order: 0
      )

      entity = repository.find_id(orm_assignment.id)
      result = repository.update_with_requirements(entity, [])

      _(result.requirements_loaded?).must_equal true
      _(result.submission_requirements.empty?).must_equal true
      _(Tyto::SubmissionRequirement.where(assignment_id: orm_assignment.id).count).must_equal 0
    end

    it 'raises error for non-existent assignment' do
      entity = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: 999_999,
        course_id: orm_course.id,
        title: 'Ghost',
        status: 'draft',
        created_at: nil,
        updated_at: nil
      )

      _ { repository.update_with_requirements(entity, []) }.must_raise RuntimeError
    end
  end

  describe '#delete' do
    it 'deletes existing assignment and returns true' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'To Delete',
        status: 'draft',
        allow_late_resubmit: false
      )

      result = repository.delete(orm_assignment.id)

      _(result).must_equal true
      _(repository.find_id(orm_assignment.id)).must_be_nil
    end

    it 'returns false for non-existent assignment' do
      result = repository.delete(999_999)

      _(result).must_equal false
    end

    it 'cascades delete to submission requirements' do
      orm_assignment = Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'With Reqs',
        status: 'draft',
        allow_late_resubmit: false
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: orm_assignment.id,
        submission_format: 'file',
        description: 'Source',
        sort_order: 0
      )

      repository.delete(orm_assignment.id)

      _(Tyto::SubmissionRequirement.where(assignment_id: orm_assignment.id).count).must_equal 0
    end
  end

  describe 'round-trip' do
    it 'maintains data integrity through create -> find -> update -> find cycle' do
      original = Tyto::Domain::Assignments::Entities::Assignment.new(
        id: nil,
        course_id: orm_course.id,
        event_id: orm_event.id,
        title: 'Round Trip',
        description: 'Testing full cycle',
        due_at: now + 7 * one_day,
        allow_late_resubmit: true,
        created_at: nil,
        updated_at: nil
      )

      created = repository.create(original)
      _(created.id).wont_be_nil

      found = repository.find_id(created.id)
      _(found.title).must_equal 'Round Trip'
      _(found.event_id).must_equal orm_event.id
      _(found.allow_late_resubmit).must_equal true

      modified = found.new(title: 'Updated Round Trip', status: 'published')
      updated = repository.update(modified)
      _(updated.title).must_equal 'Updated Round Trip'
      _(updated.status).must_equal 'published'

      final = repository.find_id(created.id)
      _(final.title).must_equal 'Updated Round Trip'
      _(final.status).must_equal 'published'
      _(final.event_id).must_equal orm_event.id
    end
  end

  describe '#course_has_assignments?' do
    it 'returns false when the course has no assignments' do
      _(repository.course_has_assignments?(orm_course.id)).must_equal false
    end

    it 'returns true when the course has any assignment and no status filter is given' do
      Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'Draft only',
        status: 'draft'
      )

      _(repository.course_has_assignments?(orm_course.id)).must_equal true
    end

    it 'returns false with statuses: ["published"] when only drafts exist' do
      Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'Draft only',
        status: 'draft'
      )

      _(repository.course_has_assignments?(orm_course.id, statuses: ['published'])).must_equal false
    end

    it 'returns true with statuses: ["published"] when at least one published assignment exists' do
      Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'Published one',
        status: 'published'
      )

      _(repository.course_has_assignments?(orm_course.id, statuses: ['published'])).must_equal true
    end

    it 'returns true with multi-status filter when one matching status exists' do
      Tyto::Assignment.create(
        course_id: orm_course.id,
        title: 'Draft only',
        status: 'draft'
      )

      _(repository.course_has_assignments?(
        orm_course.id, statuses: %w[draft published disabled]
      )).must_equal true
    end

    it 'scopes by course_id (assignments in another course do not count)' do
      other_course = Tyto::Course.create(name: 'Other Course')
      Tyto::Assignment.create(
        course_id: other_course.id,
        title: 'In another course',
        status: 'published'
      )

      _(repository.course_has_assignments?(orm_course.id)).must_equal false
    end
  end
end
