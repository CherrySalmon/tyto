# frozen_string_literal: true

require_relative '../../spec_helper'

describe Tyto::CoursePolicy do
  let(:account) { Tyto::Account.create(email: 'test@example.com', name: 'Test User') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }

  def create_enrollment(roles:)
    Tyto::Entity::Enrollment.new(
      id: 1,
      account_id: account.id,
      course_id: course.id,
      account_email: account.email,
      account_name: account.name,
      roles:,
      created_at: nil,
      updated_at: nil
    )
  end

  describe 'global role checks (admin, creator)' do
    describe 'with admin role' do
      let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['admin']) }
      let(:policy) { Tyto::CoursePolicy.new(requestor) }

      it 'allows viewing all courses' do
        _(policy.can_view_all?).must_equal true
      end

      it 'denies create without creator role' do
        _(policy.can_create?).must_equal false
      end

      it 'allows delete (admin can delete any course)' do
        _(policy.can_delete?).must_equal true
      end
    end

    describe 'with creator role' do
      let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator']) }
      let(:policy) { Tyto::CoursePolicy.new(requestor) }

      it 'allows creating courses' do
        _(policy.can_create?).must_equal true
      end

      it 'denies view_all without admin role' do
        _(policy.can_view_all?).must_equal false
      end
    end

    describe 'with member role (no special permissions)' do
      let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member']) }
      let(:policy) { Tyto::CoursePolicy.new(requestor) }

      it 'denies global operations' do
        _(policy.can_view_all?).must_equal false
        _(policy.can_create?).must_equal false
      end
    end
  end

  describe 'course-specific role checks with enrollment' do
    let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member']) }

    describe 'with owner enrollment' do
      let(:enrollment) { create_enrollment(roles: ['owner']) }
      let(:policy) { Tyto::CoursePolicy.new(requestor, enrollment) }

      it 'allows view, update, and delete' do
        _(policy.can_view?).must_equal true
        _(policy.can_update?).must_equal true
        _(policy.can_delete?).must_equal true
      end
    end

    describe 'with instructor enrollment' do
      let(:enrollment) { create_enrollment(roles: ['instructor']) }
      let(:policy) { Tyto::CoursePolicy.new(requestor, enrollment) }

      it 'allows view and update but not delete' do
        _(policy.can_view?).must_equal true
        _(policy.can_update?).must_equal true
        _(policy.can_delete?).must_equal false
      end
    end

    describe 'with staff enrollment' do
      let(:enrollment) { create_enrollment(roles: ['staff']) }
      let(:policy) { Tyto::CoursePolicy.new(requestor, enrollment) }

      it 'allows view and update but not delete' do
        _(policy.can_view?).must_equal true
        _(policy.can_update?).must_equal true
        _(policy.can_delete?).must_equal false
      end
    end

    describe 'with student enrollment' do
      let(:enrollment) { create_enrollment(roles: ['student']) }
      let(:policy) { Tyto::CoursePolicy.new(requestor, enrollment) }

      it 'allows view but not update or delete' do
        _(policy.can_view?).must_equal true
        _(policy.can_update?).must_equal false
        _(policy.can_delete?).must_equal false
      end
    end

    describe 'with nil enrollment (not enrolled)' do
      let(:policy) { Tyto::CoursePolicy.new(requestor, nil) }

      it 'denies course-specific operations' do
        _(policy.can_view?).must_equal false
        _(policy.can_update?).must_equal false
        _(policy.can_delete?).must_equal false
      end
    end
  end

  describe '#summary' do
    let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['admin']) }
    let(:enrollment) { create_enrollment(roles: ['owner']) }
    let(:policy) { Tyto::CoursePolicy.new(requestor, enrollment) }

    it 'returns hash of all permissions' do
      summary = policy.summary

      _(summary).must_be_kind_of Hash
      _(summary[:can_view_all]).must_equal true
      _(summary[:can_view]).must_equal true
      _(summary[:can_create]).must_equal false
      _(summary[:can_update]).must_equal true
      _(summary[:can_delete]).must_equal true
    end
  end
end
