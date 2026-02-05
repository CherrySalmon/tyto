# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Domain::Accounts::Values::SystemRoles do
  describe '.from' do
    it 'creates SystemRoles from array' do
      roles = Tyto::Domain::Accounts::Values::SystemRoles.from(%w[admin creator])

      _(roles.to_a).must_equal %w[admin creator]
    end

    it 'handles empty array' do
      roles = Tyto::Domain::Accounts::Values::SystemRoles.from([])

      _(roles.to_a).must_equal []
      _(roles.empty?).must_equal true
    end

    it 'handles nil' do
      roles = Tyto::Domain::Accounts::Values::SystemRoles.from(nil)

      _(roles.to_a).must_equal []
    end
  end

  describe '#has?' do
    it 'returns true when role is present' do
      roles = Tyto::Domain::Accounts::Values::SystemRoles.from(['admin'])

      _(roles.has?('admin')).must_equal true
      _(roles.has?(:admin)).must_equal true
    end

    it 'returns false when role is absent' do
      roles = Tyto::Domain::Accounts::Values::SystemRoles.from(['admin'])

      _(roles.has?('creator')).must_equal false
    end
  end

  describe '#include?' do
    it 'is an alias for has?' do
      roles = Tyto::Domain::Accounts::Values::SystemRoles.from(['admin'])

      _(roles.include?('admin')).must_equal true
      _(roles.include?('creator')).must_equal false
    end
  end

  describe 'predicates' do
    it '#admin? returns true when admin role present' do
      roles = Tyto::Domain::Accounts::Values::SystemRoles.from(['admin'])

      _(roles.admin?).must_equal true
      _(roles.creator?).must_equal false
      _(roles.member?).must_equal false
    end

    it '#creator? returns true when creator role present' do
      roles = Tyto::Domain::Accounts::Values::SystemRoles.from(['creator'])

      _(roles.creator?).must_equal true
    end

    it '#member? returns true when member role present' do
      roles = Tyto::Domain::Accounts::Values::SystemRoles.from(['member'])

      _(roles.member?).must_equal true
    end
  end

  describe 'collection queries' do
    let(:roles) { Tyto::Domain::Accounts::Values::SystemRoles.from(%w[admin creator]) }

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
      _(arr).must_equal %w[admin creator]
    end

    it '#loaded? returns true' do
      _(roles.loaded?).must_equal true
    end
  end

  describe 'validation' do
    it 'rejects invalid role names' do
      _ { Tyto::Domain::Accounts::Values::SystemRoles.from(['invalid_role']) }
        .must_raise Dry::Struct::Error
    end

    it 'accepts course roles (for AuthCapability compatibility)' do
      roles = Tyto::Domain::Accounts::Values::SystemRoles.from(['owner', 'student'])

      _(roles.to_a).must_equal %w[owner student]
    end
  end
end

describe Tyto::Domain::Accounts::Values::NullSystemRoles do
  let(:null_roles) { Tyto::Domain::Accounts::Values::NullSystemRoles.new }

  describe '#has?' do
    it 'raises NotLoadedError' do
      _ { null_roles.has?('admin') }
        .must_raise Tyto::Domain::Accounts::Values::NullSystemRoles::NotLoadedError
    end
  end

  describe '#include?' do
    it 'raises NotLoadedError' do
      _ { null_roles.include?('admin') }
        .must_raise Tyto::Domain::Accounts::Values::NullSystemRoles::NotLoadedError
    end
  end

  describe 'predicates' do
    it '#admin? raises NotLoadedError' do
      _ { null_roles.admin? }
        .must_raise Tyto::Domain::Accounts::Values::NullSystemRoles::NotLoadedError
    end

    it '#creator? raises NotLoadedError' do
      _ { null_roles.creator? }
        .must_raise Tyto::Domain::Accounts::Values::NullSystemRoles::NotLoadedError
    end

    it '#member? raises NotLoadedError' do
      _ { null_roles.member? }
        .must_raise Tyto::Domain::Accounts::Values::NullSystemRoles::NotLoadedError
    end
  end

  describe 'collection queries' do
    it '#any? raises NotLoadedError' do
      _ { null_roles.any? }
        .must_raise Tyto::Domain::Accounts::Values::NullSystemRoles::NotLoadedError
    end

    it '#empty? raises NotLoadedError' do
      _ { null_roles.empty? }
        .must_raise Tyto::Domain::Accounts::Values::NullSystemRoles::NotLoadedError
    end

    it '#count raises NotLoadedError' do
      _ { null_roles.count }
        .must_raise Tyto::Domain::Accounts::Values::NullSystemRoles::NotLoadedError
    end

    it '#to_a raises NotLoadedError' do
      _ { null_roles.to_a }
        .must_raise Tyto::Domain::Accounts::Values::NullSystemRoles::NotLoadedError
    end
  end

  describe '#loaded?' do
    it 'returns false' do
      _(null_roles.loaded?).must_equal false
    end
  end
end
