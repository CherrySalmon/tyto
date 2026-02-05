# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Value::NullTimeRange' do
  let(:null_range) { Tyto::Value::NullTimeRange.new }

  describe 'attributes' do
    it 'returns nil for start_at' do
      _(null_range.start_at).must_be_nil
    end

    it 'returns nil for end_at' do
      _(null_range.end_at).must_be_nil
    end
  end

  describe 'duration methods' do
    it 'returns 0 for duration' do
      _(null_range.duration).must_equal 0
    end

    it 'returns 0 for duration_days' do
      _(null_range.duration_days).must_equal 0
    end
  end

  describe 'predicate methods' do
    it 'returns false for active?' do
      _(null_range.active?).must_equal false
    end

    it 'returns false for upcoming?' do
      _(null_range.upcoming?).must_equal false
    end

    it 'returns false for ended?' do
      _(null_range.ended?).must_equal false
    end

    it 'returns false for overlaps?' do
      other = Tyto::Value::TimeRange.new(start_at: Time.now, end_at: Time.now + 3600)
      _(null_range.overlaps?(other)).must_equal false
    end

    it 'returns false for contains?' do
      _(null_range.contains?(Time.now)).must_equal false
    end
  end

  describe 'null object interface' do
    it 'returns true for null?' do
      _(null_range.null?).must_equal true
    end

    it 'returns false for present?' do
      _(null_range.present?).must_equal false
    end
  end

  describe 'equality' do
    it 'equals another NullTimeRange' do
      other = Tyto::Value::NullTimeRange.new
      _(null_range == other).must_equal true
    end

    it 'does not equal a real TimeRange' do
      real = Tyto::Value::TimeRange.new(start_at: Time.now, end_at: Time.now + 3600)
      _(null_range == real).must_equal false
    end
  end

  describe 'polymorphism with TimeRange' do
    it 'responds to same interface as TimeRange' do
      real = Tyto::Value::TimeRange.new(start_at: Time.now, end_at: Time.now + 3600)

      # Both should respond to the same methods
      %i[start_at end_at duration duration_days active? upcoming? ended? overlaps? contains? null? present?].each do |method|
        _(null_range.respond_to?(method)).must_equal true, "NullTimeRange should respond to #{method}"
        _(real.respond_to?(method)).must_equal true, "TimeRange should respond to #{method}"
      end
    end
  end
end
