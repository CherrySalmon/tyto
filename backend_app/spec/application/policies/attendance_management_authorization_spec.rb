# frozen_string_literal: true

require_relative '../../spec_helper'

describe Tyto::AttendanceManagementAuthorization do
  let(:account) { Tyto::Account.create(email: 'test@example.com', name: 'Test User') }
  let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member']) }

  def create_enrollment(account, course, roles:)
    Tyto::Domain::Courses::Entities::Enrollment.new(
      id: 1,
      account_id: account.id,
      course_id: course.id,
      participant: Tyto::Domain::Courses::Values::Participant.new(
        email: account.email, name: account.name
      ),
      roles: Tyto::Domain::Courses::Values::CourseRoles.from(roles),
      created_at: nil,
      updated_at: nil
    )
  end

  def create_course_with_enrollment(account, roles:)
    course = Tyto::Course.create(name: 'Test Course')
    enrollment = create_enrollment(account, course, roles: roles)
    Tyto::Domain::Courses::Entities::Course.new(
      id: course.id,
      name: course.name,
      logo: nil,
      start_at: nil,
      end_at: nil,
      created_at: nil,
      updated_at: nil,
      enrollments: Tyto::Domain::Courses::Values::Enrollments.from([enrollment])
    )
  end

  describe 'can_manage? with instructor role' do
    let(:course) { create_course_with_enrollment(account, roles: ['instructor']) }
    let(:policy) { Tyto::AttendanceManagementAuthorization.new(requestor, course) }

    it 'grants access when enrollment includes instructor role' do
      _(policy.can_manage?).must_equal true
    end
  end

  describe 'can_manage? with staff role' do
    let(:course) { create_course_with_enrollment(account, roles: ['staff']) }
    let(:policy) { Tyto::AttendanceManagementAuthorization.new(requestor, course) }

    it 'grants access when enrollment includes staff role' do
      _(policy.can_manage?).must_equal true
    end
  end

  describe 'can_manage? without instructor or staff role' do
    let(:course) { create_course_with_enrollment(account, roles: ['student']) }
    let(:policy) { Tyto::AttendanceManagementAuthorization.new(requestor, course) }

    it 'denies access when enrollment lacks instructor and staff roles' do
      _(policy.can_manage?).must_equal false
    end
  end

  describe 'can_manage? with nil course (not enrolled)' do
    let(:policy) { Tyto::AttendanceManagementAuthorization.new(requestor, nil) }

    it 'denies access when course is nil' do
      _(policy.can_manage?).must_equal false
    end
  end

  describe 'can_view_all? with owner role' do
    let(:course) { create_course_with_enrollment(account, roles: ['owner']) }
    let(:policy) { Tyto::AttendanceManagementAuthorization.new(requestor, course) }

    it 'grants view access to teaching staff (owner)' do
      _(policy.can_view_all?).must_equal true
    end
  end

  describe 'can_view_all? with student role' do
    let(:course) { create_course_with_enrollment(account, roles: ['student']) }
    let(:policy) { Tyto::AttendanceManagementAuthorization.new(requestor, course) }

    it 'denies view access to non-teaching staff' do
      _(policy.can_view_all?).must_equal false
    end
  end

  describe '#summary' do
    let(:course) { create_course_with_enrollment(account, roles: ['instructor']) }
    let(:policy) { Tyto::AttendanceManagementAuthorization.new(requestor, course) }

    it 'returns hash of management permissions' do
      summary = policy.summary

      _(summary).must_be_kind_of Hash
      _(summary[:can_view_all]).must_equal true
      _(summary[:can_manage]).must_equal true
    end
  end

  describe '#summary for student' do
    let(:course) { create_course_with_enrollment(account, roles: ['student']) }
    let(:policy) { Tyto::AttendanceManagementAuthorization.new(requestor, course) }

    it 'returns hash with denied permissions' do
      summary = policy.summary

      _(summary[:can_view_all]).must_equal false
      _(summary[:can_manage]).must_equal false
    end
  end
end
