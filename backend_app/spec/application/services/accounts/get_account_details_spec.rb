# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Accounts::GetAccountDetails do
  let(:admin) { Tyto::Account.create(email: 'admin@example.com', name: 'Admin') }
  let(:target) { Tyto::Account.create(email: 'target@example.com', name: 'Target') }
  let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: admin.id, roles: ['admin']) }

  before do
    admin.add_role(Tyto::Role.first(name: 'admin'))
    target.add_role(Tyto::Role.first(name: 'creator'))
  end

  describe '#call' do
    it 'returns the account with roles and its course memberships for an admin' do
      course = Tyto::Course.create(name: 'Detail Course')
      staff = Tyto::Role.first(name: 'staff')
      Tyto::AccountCourse.create(account_id: target.id, course_id: course.id, role_id: staff.id)

      result = Tyto::Service::Accounts::GetAccountDetails.new.call(requestor:, account_id: target.id)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      details = result.value!.message
      _(details).must_be_kind_of Tyto::Response::AccountDetails
      _(details.account.email).must_equal 'target@example.com'
      _(details.account.roles.to_a).must_equal ['creator']
      _(details.enrollments.map(&:course_name)).must_equal ['Detail Course']
      _(details.enrollments.first.roles.to_a).must_equal ['staff']
    end

    it 'returns Failure(forbidden) for a non-admin, even on their own account' do
      own = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: target.id, roles: ['creator'])

      result = Tyto::Service::Accounts::GetAccountDetails.new.call(requestor: own, account_id: target.id)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure(not_found) for an unknown account' do
      result = Tyto::Service::Accounts::GetAccountDetails.new.call(requestor:, account_id: 999_999)

      _(result.failure.status).must_equal :not_found
    end
  end
end
