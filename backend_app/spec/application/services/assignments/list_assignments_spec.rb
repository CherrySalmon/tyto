# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Assignments::ListAssignments do
  let(:owner_account) { Tyto::Account.create(email: 'owner@example.com', name: 'Owner') }
  let(:student_account) { Tyto::Account.create(email: 'student@example.com', name: 'Student') }
  let(:owner_role) { Tyto::Role.first(name: 'owner') }
  let(:student_role) { Tyto::Role.first(name: 'student') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }

  before do
    Tyto::AccountCourse.create(course_id: course.id, account_id: owner_account.id, role_id: owner_role.id)
    Tyto::AccountCourse.create(course_id: course.id, account_id: student_account.id, role_id: student_role.id)
    Tyto::Assignment.create(course_id: course.id, title: 'Draft HW', status: 'draft', allow_late_resubmit: false)
    Tyto::Assignment.create(course_id: course.id, title: 'Published HW', status: 'published', allow_late_resubmit: false)
    Tyto::Assignment.create(course_id: course.id, title: 'Disabled HW', status: 'disabled', allow_late_resubmit: false)
  end

  let(:owner_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: owner_account.id, roles: ['member'])
  end
  let(:student_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student_account.id, roles: ['member'])
  end

  describe '#call' do
    it 'returns all assignments for teaching staff' do
      result = Tyto::Service::Assignments::ListAssignments.new.call(requestor: owner_requestor, course_id: course.id)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      assignments = result.value!.message
      _(assignments.length).must_equal 3
    end

    it 'returns only published assignments for students' do
      result = Tyto::Service::Assignments::ListAssignments.new.call(requestor: student_requestor, course_id: course.id)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      assignments = result.value!.message
      _(assignments.length).must_equal 1
      _(assignments.first.status).must_equal 'published'
    end

    it 'returns Failure for non-enrolled user' do
      outsider = Tyto::Account.create(email: 'outsider@example.com', name: 'Outsider')
      outsider_requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: outsider.id, roles: ['member']
      )

      result = Tyto::Service::Assignments::ListAssignments.new.call(requestor: outsider_requestor, course_id: course.id)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end
  end
end
