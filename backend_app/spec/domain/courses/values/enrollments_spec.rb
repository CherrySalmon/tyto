# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Domain::Courses::Values::Enrollments do
  let(:now) { Time.now }
  let(:course_roles) { ->(arr) { Tyto::Domain::Courses::Values::CourseRoles.from(arr) } }
  let(:participant) { ->(email, name) { Tyto::Domain::Courses::Values::Participant.new(email:, name:) } }

  let(:owner_enrollment) do
    Tyto::Entity::Enrollment.new(
      id: 1, account_id: 10, course_id: 1,
      participant: participant.call('owner@example.com', 'Owner'),
      roles: course_roles.call(['owner']),
      created_at: now, updated_at: now
    )
  end

  let(:instructor_enrollment) do
    Tyto::Entity::Enrollment.new(
      id: 2, account_id: 20, course_id: 1,
      participant: participant.call('instructor@example.com', 'Instructor'),
      roles: course_roles.call(['instructor']),
      created_at: now, updated_at: now
    )
  end

  let(:student_enrollment) do
    Tyto::Entity::Enrollment.new(
      id: 3, account_id: 30, course_id: 1,
      participant: participant.call('student@example.com', 'Student'),
      roles: course_roles.call(['student']),
      created_at: now, updated_at: now
    )
  end

  let(:multi_role_enrollment) do
    Tyto::Entity::Enrollment.new(
      id: 4, account_id: 40, course_id: 1,
      participant: participant.call('ta@example.com', 'TA'),
      roles: course_roles.call(%w[staff student]),
      created_at: now, updated_at: now
    )
  end

  let(:all_enrollments) { [owner_enrollment, instructor_enrollment, student_enrollment, multi_role_enrollment] }

  describe '.from' do
    it 'creates collection from array of enrollments' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from(all_enrollments)

      _(collection.count).must_equal 4
    end

    it 'handles empty array' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([])

      _(collection.count).must_equal 0
      _(collection.empty?).must_equal true
    end

    it 'handles nil as empty collection' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from(nil)

      _(collection.count).must_equal 0
      _(collection.empty?).must_equal true
    end
  end

  describe '#find_by_account' do
    let(:collection) { Tyto::Domain::Courses::Values::Enrollments.from(all_enrollments) }

    it 'finds enrollment by account ID' do
      found = collection.find_by_account(30)

      _(found.participant.email).must_equal 'student@example.com'
    end

    it 'returns nil when account not found' do
      _(collection.find_by_account(999)).must_be_nil
    end
  end

  describe '#with_role' do
    let(:collection) { Tyto::Domain::Courses::Values::Enrollments.from(all_enrollments) }

    it 'returns enrollments with specific role' do
      students = collection.with_role('student')

      _(students.length).must_equal 2 # student + multi_role (has student)
    end

    it 'returns empty array when no match' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([student_enrollment])

      _(collection.with_role('owner')).must_equal []
    end
  end

  describe '#teaching_staff' do
    let(:collection) { Tyto::Domain::Courses::Values::Enrollments.from(all_enrollments) }

    it 'returns all teaching enrollments' do
      staff = collection.teaching_staff

      _(staff.length).must_equal 3 # owner, instructor, multi_role (has staff)
    end

    it 'excludes student-only enrollments' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([student_enrollment])

      _(collection.teaching_staff).must_equal []
    end
  end

  describe '#students' do
    let(:collection) { Tyto::Domain::Courses::Values::Enrollments.from(all_enrollments) }

    it 'returns all student enrollments' do
      students = collection.students

      _(students.length).must_equal 2 # student + multi_role (has student)
    end

    it 'excludes non-student enrollments' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([owner_enrollment, instructor_enrollment])

      _(collection.students).must_equal []
    end
  end

  describe '#count' do
    it 'returns number of enrollments' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from(all_enrollments)

      _(collection.count).must_equal 4
    end

    it 'returns 0 for empty collection' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([])

      _(collection.count).must_equal 0
    end
  end

  describe '#to_a' do
    it 'returns array of enrollments' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from(all_enrollments)

      arr = collection.to_a
      _(arr).must_be_kind_of Array
      _(arr.length).must_equal 4
    end
  end

  describe 'iteration' do
    it 'supports each' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([owner_enrollment, student_enrollment])
      ids = []
      collection.each { |e| ids << e.account_id }

      _(ids).must_equal [10, 30]
    end

    it 'supports map via Enumerable' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([owner_enrollment, student_enrollment])

      ids = collection.map(&:account_id)
      _(ids).must_equal [10, 30]
    end
  end

  describe '#any?' do
    it 'returns true when collection has enrollments' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([owner_enrollment])

      _(collection.any?).must_equal true
    end

    it 'returns false when collection is empty' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([])

      _(collection.any?).must_equal false
    end
  end

  describe '#empty?' do
    it 'returns true when collection is empty' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([])

      _(collection.empty?).must_equal true
    end

    it 'returns false when collection has enrollments' do
      collection = Tyto::Domain::Courses::Values::Enrollments.from([owner_enrollment])

      _(collection.empty?).must_equal false
    end
  end

  describe 'type safety' do
    it 'rejects non-Enrollment objects' do
      _ { Tyto::Domain::Courses::Values::Enrollments.from(['not an enrollment']) }
        .must_raise Dry::Struct::Error
    end
  end
end
