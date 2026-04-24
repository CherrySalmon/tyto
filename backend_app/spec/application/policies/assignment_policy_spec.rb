# frozen_string_literal: true

require_relative '../../spec_helper'

describe Tyto::AssignmentPolicy do
  let(:account) { Tyto::Account.create(email: 'test@example.com', name: 'Test User') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }

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

  describe 'teaching staff permissions' do
    let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member']) }

    describe 'with owner enrollment' do
      let(:enrollment) { create_enrollment(roles: ['owner']) }
      let(:policy) { Tyto::AssignmentPolicy.new(requestor, enrollment) }

      it 'allows full CRUD, publish, and unpublish' do
        _(policy.can_create?).must_equal true
        _(policy.can_view?).must_equal true
        _(policy.can_update?).must_equal true
        _(policy.can_delete?).must_equal true
        _(policy.can_publish?).must_equal true
        _(policy.can_unpublish?).must_equal true
      end

      it 'allows viewing draft assignments' do
        _(policy.can_view_drafts?).must_equal true
      end

      it 'denies submitting (teaching staff are not students)' do
        _(policy.can_submit?).must_equal false
      end
    end

    describe 'with instructor enrollment' do
      let(:enrollment) { create_enrollment(roles: ['instructor']) }
      let(:policy) { Tyto::AssignmentPolicy.new(requestor, enrollment) }

      it 'allows full CRUD, publish, and unpublish' do
        _(policy.can_create?).must_equal true
        _(policy.can_view?).must_equal true
        _(policy.can_update?).must_equal true
        _(policy.can_delete?).must_equal true
        _(policy.can_publish?).must_equal true
        _(policy.can_unpublish?).must_equal true
      end

      it 'allows viewing draft assignments' do
        _(policy.can_view_drafts?).must_equal true
      end

      it 'denies submitting' do
        _(policy.can_submit?).must_equal false
      end
    end

    describe 'with staff enrollment' do
      let(:enrollment) { create_enrollment(roles: ['staff']) }
      let(:policy) { Tyto::AssignmentPolicy.new(requestor, enrollment) }

      it 'allows full CRUD, publish, and unpublish' do
        _(policy.can_create?).must_equal true
        _(policy.can_view?).must_equal true
        _(policy.can_update?).must_equal true
        _(policy.can_delete?).must_equal true
        _(policy.can_publish?).must_equal true
        _(policy.can_unpublish?).must_equal true
      end

      it 'allows viewing draft assignments' do
        _(policy.can_view_drafts?).must_equal true
      end

      it 'denies submitting' do
        _(policy.can_submit?).must_equal false
      end
    end
  end

  describe 'student permissions' do
    let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member']) }
    let(:enrollment) { create_enrollment(roles: ['student']) }
    let(:policy) { Tyto::AssignmentPolicy.new(requestor, enrollment) }

    it 'allows viewing published assignments only' do
      _(policy.can_view?).must_equal true
    end

    it 'allows submitting' do
      _(policy.can_submit?).must_equal true
    end

    it 'denies creating, updating, deleting, publishing, and unpublishing' do
      _(policy.can_create?).must_equal false
      _(policy.can_update?).must_equal false
      _(policy.can_delete?).must_equal false
      _(policy.can_publish?).must_equal false
      _(policy.can_unpublish?).must_equal false
    end

    it 'denies viewing draft assignments' do
      _(policy.can_view_drafts?).must_equal false
    end
  end

  describe 'not enrolled' do
    let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member']) }
    let(:policy) { Tyto::AssignmentPolicy.new(requestor, nil) }

    it 'denies all assignment operations' do
      _(policy.can_create?).must_equal false
      _(policy.can_view?).must_equal false
      _(policy.can_update?).must_equal false
      _(policy.can_delete?).must_equal false
      _(policy.can_publish?).must_equal false
      _(policy.can_unpublish?).must_equal false
      _(policy.can_view_drafts?).must_equal false
      _(policy.can_submit?).must_equal false
    end
  end

  describe 'admin without enrollment' do
    let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['admin']) }
    let(:policy) { Tyto::AssignmentPolicy.new(requestor, nil) }

    it 'denies assignment operations (admin needs enrollment for course-scoped resources)' do
      _(policy.can_create?).must_equal false
      _(policy.can_view?).must_equal false
      _(policy.can_update?).must_equal false
      _(policy.can_delete?).must_equal false
      _(policy.can_publish?).must_equal false
      _(policy.can_unpublish?).must_equal false
      _(policy.can_submit?).must_equal false
    end
  end

  describe '#summary' do
    let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member']) }
    let(:enrollment) { create_enrollment(roles: ['instructor']) }
    let(:policy) { Tyto::AssignmentPolicy.new(requestor, enrollment) }

    it 'returns hash of all permissions' do
      summary = policy.summary

      _(summary).must_be_kind_of Hash
      _(summary[:can_create]).must_equal true
      _(summary[:can_view]).must_equal true
      _(summary[:can_update]).must_equal true
      _(summary[:can_delete]).must_equal true
      _(summary[:can_publish]).must_equal true
      _(summary[:can_unpublish]).must_equal true
      _(summary[:can_view_drafts]).must_equal true
      _(summary[:can_submit]).must_equal false
    end
  end
end
