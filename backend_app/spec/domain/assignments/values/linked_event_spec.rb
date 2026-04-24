# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Domain::Assignments::Values::LinkedEvent' do
  let(:now) { Time.now }
  let(:one_hour) { 60 * 60 }

  it 'constructs with id, name, start_at, end_at' do
    event = Tyto::Domain::Assignments::Values::LinkedEvent.new(
      id: 7,
      name: 'Week 1 Lecture',
      start_at: now,
      end_at: now + one_hour
    )

    _(event.id).must_equal 7
    _(event.name).must_equal 'Week 1 Lecture'
    _(event.start_at).must_be_close_to(now, 1)
    _(event.end_at).must_be_close_to(now + one_hour, 1)
  end

  it 'requires id and name' do
    _ {
      Tyto::Domain::Assignments::Values::LinkedEvent.new(
        name: 'X', start_at: now, end_at: now + one_hour
      )
    }.must_raise Dry::Struct::Error
  end

  it 'allows nil start_at and end_at' do
    event = Tyto::Domain::Assignments::Values::LinkedEvent.new(
      id: 1, name: 'Open-ended', start_at: nil, end_at: nil
    )

    _(event.start_at).must_be_nil
    _(event.end_at).must_be_nil
  end
end
