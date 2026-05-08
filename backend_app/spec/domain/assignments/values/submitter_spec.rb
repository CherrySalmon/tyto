# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Domain::Assignments::Values::Submitter' do
  it 'constructs with account_id, name, and email' do
    submitter = Tyto::Domain::Assignments::Values::Submitter.new(
      account_id: 4, name: 'Ada Lovelace', email: 'ada@example.com'
    )

    _(submitter.account_id).must_equal 4
    _(submitter.name).must_equal 'Ada Lovelace'
    _(submitter.email).must_equal 'ada@example.com'
  end

  it 'requires account_id and email' do
    _ {
      Tyto::Domain::Assignments::Values::Submitter.new(name: 'X', email: 'x@e.com')
    }.must_raise Dry::Struct::Error
  end

  it 'allows nil name (students who never set their display name)' do
    submitter = Tyto::Domain::Assignments::Values::Submitter.new(
      account_id: 5, name: nil, email: 'only@email.com'
    )

    _(submitter.name).must_be_nil
    _(submitter.email).must_equal 'only@email.com'
  end
end
