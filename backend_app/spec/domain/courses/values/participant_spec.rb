# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Domain::Courses::Values::Participant' do
  let(:participant_class) { Tyto::Domain::Courses::Values::Participant }

  describe 'creation' do
    it 'creates with all attributes' do
      participant = participant_class.new(
        email: 'alice@example.com', name: 'Alice', avatar: 'https://example.com/avatar.png'
      )

      _(participant.email).must_equal 'alice@example.com'
      _(participant.name).must_equal 'Alice'
      _(participant.avatar).must_equal 'https://example.com/avatar.png'
    end

    it 'creates with nil optional fields' do
      participant = participant_class.new(email: nil, name: nil)

      _(participant.email).must_be_nil
      _(participant.name).must_be_nil
      _(participant.avatar).must_be_nil
    end

    it 'rejects invalid email format' do
      _ { participant_class.new(email: 'not-an-email', name: 'Test') }
        .must_raise Dry::Struct::Error
    end
  end

  describe '#display_name' do
    it 'returns name when present' do
      participant = participant_class.new(email: 'alice@example.com', name: 'Alice')

      _(participant.display_name).must_equal 'Alice'
    end

    it 'falls back to email when name is nil' do
      participant = participant_class.new(email: 'alice@example.com', name: nil)

      _(participant.display_name).must_equal 'alice@example.com'
    end

    it 'returns nil when both name and email are nil' do
      participant = participant_class.new(email: nil, name: nil)

      _(participant.display_name).must_be_nil
    end
  end

  describe 'value semantics' do
    it 'is equal when attributes match' do
      a = participant_class.new(email: 'alice@example.com', name: 'Alice')
      b = participant_class.new(email: 'alice@example.com', name: 'Alice')

      _(a).must_equal b
    end

    it 'is not equal when attributes differ' do
      a = participant_class.new(email: 'alice@example.com', name: 'Alice')
      b = participant_class.new(email: 'bob@example.com', name: 'Bob')

      _(a).wont_equal b
    end
  end
end
