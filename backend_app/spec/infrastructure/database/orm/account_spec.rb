# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Account do
  it 'stamps created_at and updated_at on create' do
    account = Tyto::Account.create(email: 'stamped@example.com', name: 'Stamped')

    _(account.created_at).must_be_kind_of Time
    _(account.updated_at).must_be_kind_of Time
    _(account.created_at).must_be :<=, Time.now
  end

  it 'moves updated_at forward on update' do
    account = Tyto::Account.create(email: 'moving@example.com', name: 'Before')
    first = account.updated_at
    sleep 0.01
    account.update(name: 'After')

    _(account.updated_at).must_be :>=, first
  end
end
