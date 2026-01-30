# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Todo::Value::TimeRange' do
  let(:now) { Time.now }
  let(:one_hour) { 3600 }
  let(:one_day) { 24 * 60 * 60 }

  describe 'creation' do
    it 'creates a valid time range' do
      range = Todo::Value::TimeRange.new(start_at: now, end_at: now + one_hour)

      _(range.start_at).must_equal now
      _(range.end_at).must_equal now + one_hour
    end

    it 'rejects range where end_at equals start_at' do
      _ { Todo::Value::TimeRange.new(start_at: now, end_at: now) }
        .must_raise ArgumentError
    end

    it 'rejects range where end_at is before start_at' do
      _ { Todo::Value::TimeRange.new(start_at: now, end_at: now - one_hour) }
        .must_raise ArgumentError
    end
  end

  describe 'immutability' do
    it 'allows valid updates via new()' do
      range = Todo::Value::TimeRange.new(start_at: now, end_at: now + one_hour)

      # Valid update
      updated = range.new(end_at: now + 2 * one_hour)
      _(updated.end_at).must_equal now + 2 * one_hour
      _(updated.start_at).must_equal now # Original attributes preserved
    end

    # Note: dry-struct instance#new() bypasses class-level new() override,
    # so custom invariant checks only apply on initial construction.
    # Invariant enforcement for updates happens at the service/contract layer.
    it 'creates immutable copies (original unchanged)' do
      range = Todo::Value::TimeRange.new(start_at: now, end_at: now + one_hour)
      updated = range.new(end_at: now + 2 * one_hour)

      _(range.end_at).must_equal now + one_hour # Original unchanged
      _(updated.end_at).must_equal now + 2 * one_hour
    end
  end

  describe '#duration' do
    it 'returns duration in seconds' do
      range = Todo::Value::TimeRange.new(start_at: now, end_at: now + one_hour)

      _(range.duration).must_equal one_hour
    end
  end

  describe '#duration_days' do
    it 'returns duration in days' do
      range = Todo::Value::TimeRange.new(start_at: now, end_at: now + 7 * one_day)

      _(range.duration_days).must_equal 7
    end
  end

  describe '#active?' do
    it 'returns true when current time is within range' do
      range = Todo::Value::TimeRange.new(
        start_at: now - one_hour,
        end_at: now + one_hour
      )

      _(range.active?(at: now)).must_equal true
    end

    it 'returns false when current time is before range' do
      range = Todo::Value::TimeRange.new(
        start_at: now + one_hour,
        end_at: now + 2 * one_hour
      )

      _(range.active?(at: now)).must_equal false
    end

    it 'returns false when current time is after range' do
      range = Todo::Value::TimeRange.new(
        start_at: now - 2 * one_hour,
        end_at: now - one_hour
      )

      _(range.active?(at: now)).must_equal false
    end

    it 'returns true at exact start time' do
      range = Todo::Value::TimeRange.new(start_at: now, end_at: now + one_hour)

      _(range.active?(at: now)).must_equal true
    end

    it 'returns true at exact end time' do
      range = Todo::Value::TimeRange.new(start_at: now - one_hour, end_at: now)

      _(range.active?(at: now)).must_equal true
    end
  end

  describe '#upcoming?' do
    it 'returns true when range is in the future' do
      range = Todo::Value::TimeRange.new(
        start_at: now + one_hour,
        end_at: now + 2 * one_hour
      )

      _(range.upcoming?(at: now)).must_equal true
    end

    it 'returns false when range has started' do
      range = Todo::Value::TimeRange.new(
        start_at: now - one_hour,
        end_at: now + one_hour
      )

      _(range.upcoming?(at: now)).must_equal false
    end
  end

  describe '#ended?' do
    it 'returns true when range is in the past' do
      range = Todo::Value::TimeRange.new(
        start_at: now - 2 * one_hour,
        end_at: now - one_hour
      )

      _(range.ended?(at: now)).must_equal true
    end

    it 'returns false when range has not ended' do
      range = Todo::Value::TimeRange.new(
        start_at: now - one_hour,
        end_at: now + one_hour
      )

      _(range.ended?(at: now)).must_equal false
    end
  end

  describe '#overlaps?' do
    let(:range) do
      Todo::Value::TimeRange.new(start_at: now, end_at: now + 2 * one_hour)
    end

    it 'returns true for overlapping ranges' do
      other = Todo::Value::TimeRange.new(
        start_at: now + one_hour,
        end_at: now + 3 * one_hour
      )

      _(range.overlaps?(other)).must_equal true
    end

    it 'returns true when other range is contained' do
      other = Todo::Value::TimeRange.new(
        start_at: now + 30 * 60,
        end_at: now + 90 * 60
      )

      _(range.overlaps?(other)).must_equal true
    end

    it 'returns false for non-overlapping ranges' do
      other = Todo::Value::TimeRange.new(
        start_at: now + 3 * one_hour,
        end_at: now + 4 * one_hour
      )

      _(range.overlaps?(other)).must_equal false
    end
  end

  describe '#contains?' do
    let(:range) do
      Todo::Value::TimeRange.new(start_at: now, end_at: now + 2 * one_hour)
    end

    it 'returns true for time within range' do
      _(range.contains?(now + one_hour)).must_equal true
    end

    it 'returns true at boundaries' do
      _(range.contains?(now)).must_equal true
      _(range.contains?(now + 2 * one_hour)).must_equal true
    end

    it 'returns false for time outside range' do
      _(range.contains?(now - one_hour)).must_equal false
      _(range.contains?(now + 3 * one_hour)).must_equal false
    end
  end
end
