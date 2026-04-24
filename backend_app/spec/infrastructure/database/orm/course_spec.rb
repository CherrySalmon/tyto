# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Course ORM' do
  let(:owner_role) { Tyto::Role.first(name: 'owner') }
  let(:student_role) { Tyto::Role.first(name: 'student') }

  describe '#owner' do
    it 'returns the account with the owner role for the course' do
      course = Tyto::Course.create(name: 'Test Course')
      account = Tyto::Account.create(email: 'owner@example.com', name: 'Owner')
      Tyto::AccountCourse.create(course_id: course.id, account_id: account.id, role_id: owner_role.id)

      result = course.owner

      _(result).must_be_instance_of Tyto::Account
      _(result.email).must_equal 'owner@example.com'
    end

    it 'returns nil when no owner is assigned' do
      course = Tyto::Course.create(name: 'Ownerless Course')

      _(course.owner).must_be_nil
    end

    it 'does not return accounts with non-owner roles' do
      course = Tyto::Course.create(name: 'Test Course')
      account = Tyto::Account.create(email: 'student@example.com', name: 'Student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: account.id, role_id: student_role.id)

      _(course.owner).must_be_nil
    end
  end
end
