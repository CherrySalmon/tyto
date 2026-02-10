# frozen_string_literal: true

require_relative '../../spec_helper'

describe Tyto::EventPolicy do
  let(:account) { Tyto::Account.create(email: 'test@example.com', name: 'Test User') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }
  let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member']) }

  def create_enrollment(roles:)
    Tyto::Entity::Enrollment.new(
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
    let(:policy) { Tyto::EventPolicy.new(requestor, enrollment) }

    it 'allows all event operations' do
      _(policy.can_create?).must_equal true
      _(policy.can_view?).must_equal true
      _(policy.can_update?).must_equal true
      _(policy.can_delete?).must_equal true
    end
  end

  describe 'with instructor enrollment' do
    let(:enrollment) { create_enrollment(roles: ['instructor']) }
    let(:policy) { Tyto::EventPolicy.new(requestor, enrollment) }

    it 'allows all event operations' do
      _(policy.can_create?).must_equal true
      _(policy.can_view?).must_equal true
      _(policy.can_update?).must_equal true
      _(policy.can_delete?).must_equal true
    end
  end

  describe 'with staff enrollment' do
    let(:enrollment) { create_enrollment(roles: ['staff']) }
    let(:policy) { Tyto::EventPolicy.new(requestor, enrollment) }

    it 'allows all event operations' do
      _(policy.can_create?).must_equal true
      _(policy.can_view?).must_equal true
      _(policy.can_update?).must_equal true
      _(policy.can_delete?).must_equal true
    end
  end

  describe 'with student enrollment' do
    let(:enrollment) { create_enrollment(roles: ['student']) }
    let(:policy) { Tyto::EventPolicy.new(requestor, enrollment) }

    it 'denies all event operations' do
      _(policy.can_create?).must_equal false
      _(policy.can_view?).must_equal false
      _(policy.can_update?).must_equal false
      _(policy.can_delete?).must_equal false
    end
  end

  describe 'with nil enrollment (not enrolled)' do
    let(:policy) { Tyto::EventPolicy.new(requestor, nil) }

    it 'denies all event operations' do
      _(policy.can_create?).must_equal false
      _(policy.can_view?).must_equal false
      _(policy.can_update?).must_equal false
      _(policy.can_delete?).must_equal false
    end
  end

  describe 'with multiple roles' do
    let(:enrollment) { create_enrollment(roles: %w[instructor student]) }
    let(:policy) { Tyto::EventPolicy.new(requestor, enrollment) }

    it 'allows operations based on highest privilege' do
      _(policy.can_create?).must_equal true
      _(policy.can_view?).must_equal true
      _(policy.can_update?).must_equal true
      _(policy.can_delete?).must_equal true
    end
  end

  describe '#summary' do
    let(:enrollment) { create_enrollment(roles: ['owner']) }
    let(:policy) { Tyto::EventPolicy.new(requestor, enrollment) }

    it 'returns hash of all permissions' do
      summary = policy.summary

      _(summary).must_be_kind_of Hash
      _(summary[:can_view]).must_equal true
      _(summary[:can_create]).must_equal true
      _(summary[:can_update]).must_equal true
      _(summary[:can_delete]).must_equal true
    end
  end
end
