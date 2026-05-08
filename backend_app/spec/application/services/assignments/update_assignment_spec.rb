# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Assignments::UpdateAssignment do
  let(:owner_account) { Tyto::Account.create(email: 'owner@example.com', name: 'Owner') }
  let(:student_account) { Tyto::Account.create(email: 'student@example.com', name: 'Student') }
  let(:owner_role) { Tyto::Role.first(name: 'owner') }
  let(:student_role) { Tyto::Role.first(name: 'student') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }

  before do
    Tyto::AccountCourse.create(course_id: course.id, account_id: owner_account.id, role_id: owner_role.id)
    Tyto::AccountCourse.create(course_id: course.id, account_id: student_account.id, role_id: student_role.id)
  end

  let(:owner_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: owner_account.id, roles: ['member'])
  end
  let(:student_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student_account.id, roles: ['member'])
  end

  describe '#call' do
    it 'updates assignment metadata and returns Success' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Original', description: 'Old', status: 'draft', allow_late_resubmit: false
      )
      update_data = { 'title' => 'Updated', 'description' => 'New description' }

      result = Tyto::Service::Assignments::UpdateAssignment.new.call(
        requestor: owner_requestor, course_id: course.id,
        assignment_id: assignment.id, assignment_data: update_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
    end

    it 'allows updating metadata of published assignment' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Published', status: 'published', allow_late_resubmit: false
      )
      update_data = { 'title' => 'Updated Published', 'allow_late_resubmit' => true }

      result = Tyto::Service::Assignments::UpdateAssignment.new.call(
        requestor: owner_requestor, course_id: course.id,
        assignment_id: assignment.id, assignment_data: update_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
    end

    it 'returns Failure when student tries to update' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'HW', status: 'published', allow_late_resubmit: false
      )
      update_data = { 'title' => 'Hacked' }

      result = Tyto::Service::Assignments::UpdateAssignment.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, assignment_data: update_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-existent assignment' do
      update_data = { 'title' => 'Ghost' }

      result = Tyto::Service::Assignments::UpdateAssignment.new.call(
        requestor: owner_requestor, course_id: course.id,
        assignment_id: 999_999, assignment_data: update_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end

    it 'updates requirements for draft assignment' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft HW', status: 'draft', allow_late_resubmit: false
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: assignment.id, submission_format: 'file',
        description: 'Old requirement', sort_order: 0
      )

      update_data = {
        'title' => 'Updated Draft',
        'submission_requirements' => [
          { 'submission_format' => 'url', 'description' => 'GitHub link' },
          { 'submission_format' => 'file', 'description' => 'PDF report', 'allowed_types' => 'pdf' }
        ]
      }

      result = Tyto::Service::Assignments::UpdateAssignment.new.call(
        requestor: owner_requestor, course_id: course.id,
        assignment_id: assignment.id, assignment_data: update_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success

      reqs = Tyto::SubmissionRequirement.where(assignment_id: assignment.id).all
      _(reqs.length).must_equal 2
      _(reqs.map(&:description)).must_include 'GitHub link'
      _(reqs.map(&:description)).must_include 'PDF report'
      _(reqs.map(&:description)).wont_include 'Old requirement'
    end

    it 'rejects requirements update for published assignment' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Published', status: 'published', allow_late_resubmit: false
      )

      update_data = {
        'submission_requirements' => [
          { 'submission_format' => 'file', 'description' => 'Sneaky requirement' }
        ]
      }

      result = Tyto::Service::Assignments::UpdateAssignment.new.call(
        requestor: owner_requestor, course_id: course.id,
        assignment_id: assignment.id, assignment_data: update_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end
  end
end
