# frozen_string_literal: true

require_relative '../../spec_helper'

describe Tyto::AttendancePolicy do
  let(:account) { Tyto::Account.create(email: 'test@example.com', name: 'Test User') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }
  let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member']) }

  def create_enrollment(roles:)
    Tyto::Entity::Enrollment.new(
      id: 1,
      account_id: account.id,
      course_id: course.id,
      account_email: account.email,
      account_name: account.name,
      roles: Tyto::Domain::Courses::Values::CourseRoles.from(roles),
      created_at: nil,
      updated_at: nil
    )
  end

  describe 'with owner enrollment' do
    let(:enrollment) { create_enrollment(roles: ['owner']) }
    let(:policy) { Tyto::AttendancePolicy.new(requestor, enrollment) }

    it 'allows all attendance operations including view_all' do
      _(policy.can_create?).must_equal true
      _(policy.can_view?).must_equal true
      _(policy.can_view_all?).must_equal true
      _(policy.can_update?).must_equal true
    end
  end

  describe 'with instructor enrollment' do
    let(:enrollment) { create_enrollment(roles: ['instructor']) }
    let(:policy) { Tyto::AttendancePolicy.new(requestor, enrollment) }

    it 'allows all attendance operations including view_all' do
      _(policy.can_create?).must_equal true
      _(policy.can_view?).must_equal true
      _(policy.can_view_all?).must_equal true
      _(policy.can_update?).must_equal true
    end
  end

  describe 'with staff enrollment' do
    let(:enrollment) { create_enrollment(roles: ['staff']) }
    let(:policy) { Tyto::AttendancePolicy.new(requestor, enrollment) }

    it 'allows all attendance operations including view_all' do
      _(policy.can_create?).must_equal true
      _(policy.can_view?).must_equal true
      _(policy.can_view_all?).must_equal true
      _(policy.can_update?).must_equal true
    end
  end

  describe 'with student enrollment' do
    let(:enrollment) { create_enrollment(roles: ['student']) }
    let(:policy) { Tyto::AttendancePolicy.new(requestor, enrollment) }

    it 'allows own attendance operations but not view_all' do
      _(policy.can_create?).must_equal true
      _(policy.can_view?).must_equal true
      _(policy.can_view_all?).must_equal false
      _(policy.can_update?).must_equal true
    end
  end

  describe 'with nil enrollment (not enrolled)' do
    let(:policy) { Tyto::AttendancePolicy.new(requestor, nil) }

    it 'denies all attendance operations' do
      _(policy.can_create?).must_equal false
      _(policy.can_view?).must_equal false
      _(policy.can_view_all?).must_equal false
      _(policy.can_update?).must_equal false
    end
  end

  describe '#summary' do
    let(:enrollment) { create_enrollment(roles: ['student']) }
    let(:policy) { Tyto::AttendancePolicy.new(requestor, enrollment) }

    it 'returns hash of all permissions' do
      summary = policy.summary

      _(summary).must_be_kind_of Hash
      _(summary[:can_view]).must_equal true
      _(summary[:can_view_all]).must_equal false
      _(summary[:can_create]).must_equal true
      _(summary[:can_update]).must_equal true
    end
  end
end
