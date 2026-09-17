# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Courses::UpdateEnrollments do
  let(:course) { Tyto::Course.create(name: 'Enroll Course') }
  let(:owner) { Tyto::Account.create(email: 'owner@example.com', name: 'Owner') }
  let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: owner.id, roles: ['member']) }

  before do
    Tyto::AccountCourse.create(account_id: owner.id, course_id: course.id, role_id: Tyto::Role.first(name: 'owner').id)
  end

  def course_roles_of(email)
    account = Tyto::Account.first(email:)
    Tyto::AccountCourse.where(account_id: account.id, course_id: course.id).map { |ac| ac.role.name }.sort
  end

  describe '#call' do
    it 'creates missing accounts as members and sets each course role' do
      Tyto::Account.create(email: 'already@example.com', name: 'Already')
      enrolled_data = [
        { 'email' => 'fresh@example.com', 'roles' => 'student' },
        { 'email' => 'already@example.com', 'roles' => 'instructor, staff' }
      ]

      result = Tyto::Service::Courses::UpdateEnrollments.new.call(requestor:, course_id: course.id, enrolled_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(Tyto::Account.first(email: 'fresh@example.com').roles.map(&:name)).must_equal ['member']
      _(course_roles_of('fresh@example.com')).must_equal ['student']
      _(course_roles_of('already@example.com')).must_equal %w[instructor staff]
    end

    it 'creates no accounts when creating one of them fails' do
      original = Tyto::Account.method(:create)
      calls = 0
      failing = lambda do |*args, **kwargs|
        calls += 1
        raise Sequel::DatabaseError, 'simulated failure' if calls == 2

        original.call(*args, **kwargs)
      end
      enrolled_data = [
        { 'email' => 'one@example.com', 'roles' => 'student' },
        { 'email' => 'two@example.com', 'roles' => 'student' }
      ]

      result = Tyto::Account.stub(:create, failing) do
        Tyto::Service::Courses::UpdateEnrollments.new.call(requestor:, course_id: course.id, enrolled_data:)
      end

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :internal_error
      _(Tyto::Account.first(email: 'one@example.com')).must_be_nil
      _(Tyto::Account.first(email: 'two@example.com')).must_be_nil
    end
  end
end
