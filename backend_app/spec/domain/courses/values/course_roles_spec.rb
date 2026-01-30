# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Domain::Courses::Values::CourseRoles do
  describe '.from' do
    it 'creates CourseRoles from array' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(%w[owner instructor])

      _(roles.to_a).must_equal %w[owner instructor]
    end

    it 'handles empty array' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from([])

      _(roles.to_a).must_equal []
      _(roles.empty?).must_equal true
    end

    it 'handles nil' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(nil)

      _(roles.to_a).must_equal []
    end
  end

  describe '#has?' do
    it 'returns true when role is present' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['owner'])

      _(roles.has?('owner')).must_equal true
      _(roles.has?(:owner)).must_equal true
    end

    it 'returns false when role is absent' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['owner'])

      _(roles.has?('student')).must_equal false
    end
  end

  describe '#include?' do
    it 'is an alias for has?' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['owner'])

      _(roles.include?('owner')).must_equal true
      _(roles.include?('student')).must_equal false
    end
  end

  describe 'predicates' do
    it '#owner? returns true when owner role present' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['owner'])

      _(roles.owner?).must_equal true
      _(roles.instructor?).must_equal false
      _(roles.staff?).must_equal false
      _(roles.student?).must_equal false
    end

    it '#instructor? returns true when instructor role present' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['instructor'])

      _(roles.instructor?).must_equal true
    end

    it '#staff? returns true when staff role present' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['staff'])

      _(roles.staff?).must_equal true
    end

    it '#student? returns true when student role present' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['student'])

      _(roles.student?).must_equal true
    end
  end

  describe '#teaching?' do
    it 'returns true for owner' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['owner'])

      _(roles.teaching?).must_equal true
    end

    it 'returns true for instructor' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['instructor'])

      _(roles.teaching?).must_equal true
    end

    it 'returns true for staff' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['staff'])

      _(roles.teaching?).must_equal true
    end

    it 'returns false for student only' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(['student'])

      _(roles.teaching?).must_equal false
    end

    it 'returns true when mixed roles include teaching role' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(%w[student instructor])

      _(roles.teaching?).must_equal true
    end
  end

  describe 'collection queries' do
    let(:roles) { Tyto::Domain::Courses::Values::CourseRoles.from(%w[owner instructor]) }

    it '#any? returns true when has roles' do
      _(roles.any?).must_equal true
    end

    it '#empty? returns false when has roles' do
      _(roles.empty?).must_equal false
    end

    it '#count returns number of roles' do
      _(roles.count).must_equal 2
    end

    it '#to_a returns array copy' do
      arr = roles.to_a
      _(arr).must_equal %w[owner instructor]
    end
  end

  describe 'validation' do
    it 'rejects invalid role names' do
      _ { Tyto::Domain::Courses::Values::CourseRoles.from(['admin']) }
        .must_raise Dry::Struct::Error
    end

    it 'accepts all valid course roles' do
      roles = Tyto::Domain::Courses::Values::CourseRoles.from(%w[owner instructor staff student])

      _(roles.count).must_equal 4
    end
  end
end
