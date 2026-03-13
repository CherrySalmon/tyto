# frozen_string_literal: true

require_relative '../../spec_helper'

describe Tyto::Policy::Attendance do
  let(:account) { Tyto::Account.create(email: 'test@example.com', name: 'Test User') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }
  let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member']) }

  def create_enrollment(roles:)
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

  describe 'with owner enrollment' do
    let(:enrollment) { create_enrollment(roles: ['owner']) }
    let(:policy) { Tyto::Policy::Attendance.new(requestor, enrollment) }

    it 'allows self-service attendance operations' do
      _(policy.can_view?).must_equal true
      _(policy.can_attend?).must_equal true
    end
  end

  describe 'with instructor enrollment' do
    let(:enrollment) { create_enrollment(roles: ['instructor']) }
    let(:policy) { Tyto::Policy::Attendance.new(requestor, enrollment) }

    it 'allows self-service attendance operations' do
      _(policy.can_view?).must_equal true
      _(policy.can_attend?).must_equal true
    end
  end

  describe 'with staff enrollment' do
    let(:enrollment) { create_enrollment(roles: ['staff']) }
    let(:policy) { Tyto::Policy::Attendance.new(requestor, enrollment) }

    it 'allows self-service attendance operations' do
      _(policy.can_view?).must_equal true
      _(policy.can_attend?).must_equal true
    end
  end

  describe 'with student enrollment' do
    let(:enrollment) { create_enrollment(roles: ['student']) }
    let(:policy) { Tyto::Policy::Attendance.new(requestor, enrollment) }

    it 'allows self-service attendance operations' do
      _(policy.can_view?).must_equal true
      _(policy.can_attend?).must_equal true
    end
  end

  describe 'with nil enrollment (not enrolled)' do
    let(:policy) { Tyto::Policy::Attendance.new(requestor, nil) }

    it 'denies all self-service attendance operations' do
      _(policy.can_view?).must_equal false
      _(policy.can_attend?).must_equal false
    end
  end

  describe '#summary' do
    let(:enrollment) { create_enrollment(roles: ['student']) }
    let(:policy) { Tyto::Policy::Attendance.new(requestor, enrollment) }

    it 'returns hash of self-service permissions only' do
      summary = policy.summary

      _(summary).must_be_kind_of Hash
      _(summary[:can_view]).must_equal true
      _(summary[:can_attend]).must_equal true
      _(summary.keys).must_equal %i[can_view can_attend]
    end
  end
end
