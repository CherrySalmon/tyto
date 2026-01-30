# frozen_string_literal: true

require_relative '../../../spec_helper'

# Test class that includes the concern
class CoordinateValidationTestService
  include Dry::Monads::Result::Mixin
  include Tyto::Service::CoordinateValidation

  def bad_request(message)
    { status: 400, message: }
  end
end

describe 'Tyto::Service::CoordinateValidation' do
  let(:service) { CoordinateValidationTestService.new }

  describe '#validate_coordinates' do
    it 'returns success with nil coordinates when both are nil' do
      result = service.validate_coordinates(nil, nil)

      _(result).must_be :success?
      _(result.value!).must_equal(longitude: nil, latitude: nil)
    end

    it 'returns success with valid coordinates' do
      result = service.validate_coordinates(121.5654, 25.0330)

      _(result).must_be :success?
      _(result.value![:longitude]).must_equal 121.5654
      _(result.value![:latitude]).must_equal 25.0330
    end

    it 'converts string coordinates to floats' do
      result = service.validate_coordinates('121.5654', '25.0330')

      _(result).must_be :success?
      _(result.value![:longitude]).must_equal 121.5654
      _(result.value![:latitude]).must_equal 25.0330
    end

    it 'returns failure when only longitude is provided' do
      result = service.validate_coordinates(121.0, nil)

      _(result).must_be :failure?
      _(result.failure[:message]).must_equal 'Both longitude and latitude must be provided together'
    end

    it 'returns failure when only latitude is provided' do
      result = service.validate_coordinates(nil, 25.0)

      _(result).must_be :failure?
      _(result.failure[:message]).must_equal 'Both longitude and latitude must be provided together'
    end

    it 'returns failure for longitude out of range (too low)' do
      result = service.validate_coordinates(-181.0, 25.0)

      _(result).must_be :failure?
      _(result.failure[:message]).must_equal 'Longitude must be between -180 and 180'
    end

    it 'returns failure for longitude out of range (too high)' do
      result = service.validate_coordinates(181.0, 25.0)

      _(result).must_be :failure?
      _(result.failure[:message]).must_equal 'Longitude must be between -180 and 180'
    end

    it 'returns failure for latitude out of range (too low)' do
      result = service.validate_coordinates(121.0, -91.0)

      _(result).must_be :failure?
      _(result.failure[:message]).must_equal 'Latitude must be between -90 and 90'
    end

    it 'returns failure for latitude out of range (too high)' do
      result = service.validate_coordinates(121.0, 91.0)

      _(result).must_be :failure?
      _(result.failure[:message]).must_equal 'Latitude must be between -90 and 90'
    end

    it 'accepts boundary values' do
      result = service.validate_coordinates(-180.0, -90.0)

      _(result).must_be :success?
      _(result.value!).must_equal(longitude: -180.0, latitude: -90.0)
    end
  end
end
