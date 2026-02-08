# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Policy::RoleAssignment' do
  describe '.assignable_roles' do
    it 'returns all course roles for owner' do
      result = Tyto::Policy::RoleAssignment.assignable_roles('owner')

      _(result).must_equal %w[owner instructor staff student]
    end

    it 'returns staff and student for instructor' do
      result = Tyto::Policy::RoleAssignment.assignable_roles('instructor')

      _(result).must_equal %w[staff student]
    end

    it 'returns student for staff' do
      result = Tyto::Policy::RoleAssignment.assignable_roles('staff')

      _(result).must_equal %w[student]
    end

    it 'returns empty array for student' do
      result = Tyto::Policy::RoleAssignment.assignable_roles('student')

      _(result).must_equal []
    end

    it 'raises UnknownRoleError for unknown role' do
      _(-> { Tyto::Policy::RoleAssignment.assignable_roles('unknown') })
        .must_raise Tyto::Policy::RoleAssignment::UnknownRoleError
    end
  end

  describe '.for_enrollment' do
    it 'uses highest role from enrollment' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(%w[instructor student])

      result = Tyto::Policy::RoleAssignment.for_enrollment(roles)

      _(result).must_equal %w[staff student]
    end

    it 'returns all roles when enrollment includes owner' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(%w[owner instructor])

      result = Tyto::Policy::RoleAssignment.for_enrollment(roles)

      _(result).must_equal %w[owner instructor staff student]
    end

    it 'returns empty array for empty roles' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from([])

      result = Tyto::Policy::RoleAssignment.for_enrollment(roles)

      _(result).must_equal []
    end
  end

  describe 'HIERARCHY' do
    it 'defines four course roles in descending order' do
      _(Tyto::Policy::RoleAssignment::HIERARCHY).must_equal %w[owner instructor staff student]
    end
  end
end
