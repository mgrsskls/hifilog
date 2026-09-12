# frozen_string_literal: true

require 'test_helper'

# Source-side gate behaviour. The fixture catalogue is a role-adjacent chain: sub category one is
# Headphone Amplifiers, two is Over-Ear Headphones, three is Pre-Amp / Driver Tubes.
class RelatedProducts::ResolverTest < ActiveSupport::TestCase
  def roles_for(product)
    RelatedProducts::Resolver.new(product:).call.map(&:role)
  end

  test 'a tube amplifier reaches driver tubes' do
    assert_includes roles_for(products(:tube_headphone_amp)), :tube_preamp
  end

  test 'a solid state amplifier does not reach driver tubes' do
    assert_not_includes roles_for(products(:solid_state_headphone_amp)), :tube_preamp
  end

  test 'an amplifier with no amplifier_type does not reach driver tubes' do
    # Fail closed (docs §5.4): unfilled is not the same as known-not-to-be-a-valve-amp, and
    # recommending KT88s for a Class D amplifier is the error the gate exists to prevent.
    product = products(:one)

    assert_nil product.custom_attributes&.dig('amplifier_type')
    assert_not_includes roles_for(product), :tube_preamp
  end

  test 'an amplifier reaches headphones' do
    assert_includes roles_for(products(:tube_headphone_amp)), :headphone
  end

  test 'a wired headphone reaches headphone amplifiers through its specialisation' do
    assert_includes roles_for(products(:wired_headphone)), :headphone_amp
  end

  test 'a headphone with no connection type falls back to its common edges only' do
    # docs §5.1 shape D: an unresolvable specialisation falls back to the edges valid either way
    # -- never to a guessed one. The headphone role's only common edge is digital audio players,
    # a sub category the fixture catalogue does not have, so nothing resolves.
    product = products(:two)

    assert_nil product.custom_attributes&.dig('headphone_connection_type')
    assert_not_includes roles_for(product), :headphone_amp
  end

  test 'targets carry the option ids their candidates must hold' do
    target = RelatedProducts::Resolver.new(product: products(:wired_headphone)).call
                                      .find { |candidate| candidate.role == :headphone_amp }

    assert target, 'expected a headphone amplifier target'
    assert_empty target.gates, 'headphone amplifiers are reached without a target gate'
  end

  test 'a specialised target resolves its implicit gate to stored option ids' do
    target = RelatedProducts::Resolver.new(product: products(:tube_headphone_amp)).call
                                      .find { |candidate| candidate.role == :headphone }
    gate = target.gates.find { |candidate| candidate.attribute == 'headphone_connection_type' }

    assert gate, 'expected the wired-only gate on the headphone target'
    assert_equal ['1'], gate.option_ids
    assert_not gate.negate
  end

  test 'a product never targets a sub category it is itself in' do
    product = products(:tube_headphone_amp)
    headphone_amplifiers = sub_categories(:one)

    RelatedProducts::Resolver.new(product:).call.each do |target|
      assert_not_includes target.sub_category_ids, headphone_amplifiers.id
    end
  end
end
