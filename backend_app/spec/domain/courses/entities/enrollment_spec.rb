# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Entity::Enrollment' do
  let(:now) { Time.now }

  # Helper to create CourseRoles
  let(:course_roles) { ->(arr) { Tyto::Domain::Courses::Values::CourseRoles.from(arr) } }

  let(:participant) do
    Tyto::Domain::Courses::Values::Participant.new(
      email: 'student@example.com', name: 'Test Student'
    )
  end

  let(:valid_attributes) do
    {
      id: 1,
      account_id: 10,
      course_id: 20,
      participant: participant,
      roles: course_roles.call(['student']),
      created_at: now,
      updated_at: now
    }
  end

  describe 'creation' do
    it 'creates a valid enrollment' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes)

      _(enrollment.id).must_equal 1
      _(enrollment.account_id).must_equal 10
      _(enrollment.course_id).must_equal 20
      _(enrollment.participant.email).must_equal 'student@example.com'
      _(enrollment.roles.to_a).must_equal ['student']
    end

    it 'creates enrollment with multiple roles' do
      attrs = valid_attributes.merge(roles: course_roles.call(%w[instructor staff]))
      enrollment = Tyto::Entity::Enrollment.new(attrs)

      _(enrollment.roles.to_a).must_equal %w[instructor staff]
    end

    it 'creates enrollment with all roles' do
      attrs = valid_attributes.merge(roles: course_roles.call(%w[owner instructor staff student]))
      enrollment = Tyto::Entity::Enrollment.new(attrs)

      _(enrollment.roles.count).must_equal 4
    end

    it 'creates enrollment without optional attributes' do
      enrollment = Tyto::Entity::Enrollment.new(
        id: nil,
        account_id: 10,
        course_id: 20,
        participant: Tyto::Domain::Courses::Values::Participant.new(email: nil, name: nil),
        roles: course_roles.call([]),
        created_at: nil,
        updated_at: nil
      )

      _(enrollment.account_id).must_equal 10
      _(enrollment.course_id).must_equal 20
      _(enrollment.roles.to_a).must_equal []
    end

    it 'requires account_id' do
      _ { Tyto::Entity::Enrollment.new(valid_attributes.merge(account_id: nil)) }
        .must_raise Dry::Struct::Error
    end

    it 'requires course_id' do
      _ { Tyto::Entity::Enrollment.new(valid_attributes.merge(course_id: nil)) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects raw arrays (must use CourseRoles)' do
      _ { Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: ['student'])) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects invalid role names' do
      _ { Tyto::Domain::Courses::Values::CourseRoles.from(['invalid_role']) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects invalid email format in participant' do
      _ { Tyto::Domain::Courses::Values::Participant.new(email: 'invalid-email', name: 'Test') }
        .must_raise Dry::Struct::Error
    end
  end

  describe '#has_role?' do
    it 'returns true when enrollment has the role' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(%w[instructor student])))

      _(enrollment.has_role?('instructor')).must_equal true
      _(enrollment.has_role?('student')).must_equal true
    end

    it 'returns false when enrollment lacks the role' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(['student'])))

      _(enrollment.has_role?('instructor')).must_equal false
      _(enrollment.has_role?('owner')).must_equal false
    end
  end

  describe 'role predicates' do
    it 'returns true for owner?' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(['owner'])))

      _(enrollment.owner?).must_equal true
      _(enrollment.instructor?).must_equal false
    end

    it 'returns true for instructor?' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(['instructor'])))

      _(enrollment.instructor?).must_equal true
      _(enrollment.student?).must_equal false
    end

    it 'returns true for staff?' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(['staff'])))

      _(enrollment.staff?).must_equal true
    end

    it 'returns true for student?' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(['student'])))

      _(enrollment.student?).must_equal true
    end
  end

  describe '#teaching?' do
    it 'returns true for owner' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(['owner'])))

      _(enrollment.teaching?).must_equal true
    end

    it 'returns true for instructor' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(['instructor'])))

      _(enrollment.teaching?).must_equal true
    end

    it 'returns true for staff' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(['staff'])))

      _(enrollment.teaching?).must_equal true
    end

    it 'returns false for student only' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(['student'])))

      _(enrollment.teaching?).must_equal false
    end

    it 'returns true when mixed roles include teaching role' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call(%w[student instructor])))

      _(enrollment.teaching?).must_equal true
    end
  end

  describe '#active?' do
    it 'returns true when has roles' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes)

      _(enrollment.active?).must_equal true
    end

    it 'returns false when no roles' do
      enrollment = Tyto::Entity::Enrollment.new(valid_attributes.merge(roles: course_roles.call([])))

      _(enrollment.active?).must_equal false
    end
  end
end
