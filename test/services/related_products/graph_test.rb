# frozen_string_literal: true

require 'test_helper'

# Invariants over the authored pairing graph (app/services/related_products/graph.rb).
#
# These are the invariants checkable without a catalogue: the graph's internal consistency, its
# i18n coverage, and the set of edges deliberately left disabled.
#
# The invariants that need real data -- every sub category has a role, every gate names an
# attribute that exists, every option key is actually offered -- live in `rake related_products:check`
# instead. The fixture database holds 2 sub categories and 6 custom attributes against the graph's
# 45 slugs and 10 gate attributes, so here they would either fail or pass vacuously. A sub category
# added in production is something no test can see.
class RelatedProducts::GraphTest < ActiveSupport::TestCase
  Graph = RelatedProducts::Graph

  test 'no sub category is assigned to two roles' do
    duplicates = Graph::ROLES.values.flat_map { |definition| definition[:sub_categories] }
                             .tally.select { |_, count| count > 1 }.keys

    assert_empty duplicates, "sub categories assigned twice: #{duplicates.join(', ')}"
  end

  test 'every edge target resolves to a declared or specialised role' do
    unresolvable = Graph.all_targets.reject do |target|
      Graph::ROLES.key?(target) || Graph.specialised?(target)
    end

    assert_empty unresolvable, "edges point at undeclared roles: #{unresolvable.join(', ')}"
  end

  test 'no role points at itself' do
    self_edges = Graph::ROLES.filter_map do |role, definition|
      role if Graph.declared_edges(definition).any? { |edge| Graph.base_role(edge[:to]) == role }
    end

    assert_empty self_edges,
                 "roles pointing at themselves: #{self_edges.join(', ')}. Related Products offers " \
                 'companions, not alternatives.'
  end

  test 'edges with no expressible gate stay disabled' do
    disabled = Graph::ROLES.flat_map do |_role, definition|
      Graph.declared_edges(definition).select { |edge| edge[:enabled] == false }
           .map { |edge| Graph.base_role(edge[:to]) }
    end.uniq.sort

    expected = [:cable_digital, :cable_headphone, :cable_interconnect, :cable_speaker, :dac,
                :power_amp, :speaker_floor, :speaker_standmount, :streamer].sort

    assert_equal expected, disabled,
                 'the set of un-gateable edge targets changed -- see docs/pairing-graph.md §5.3. ' \
                 'The cable targets lack a usable connector attribute; the rest assume a source ' \
                 'with volume control, which nothing records.'
  end

  # Which roles are consumables is authored on the role (docs §6.3 rule 5), not listed in Query.
  # A new valve or stylus role that forgets to say so would silently be demoted for being
  # discontinued, which is backwards for a market where NOS stock is the desirable end.
  test 'the consumable roles are the declared set' do
    consumable = Graph::ROLES.select { |_role, definition| definition[:consumable] }.keys.sort

    assert_equal [:cable_headphone, :cartridge, :tube_power, :tube_preamp, :tube_rectifier].sort,
                 consumable,
                 'the consumable role set changed -- see docs/pairing-graph.md §6.3 rule 5'
  end

  test 'consumable? resolves through a specialised target' do
    assert Graph.consumable?(:cartridge)
    assert_not Graph.consumable?(:dac)
    assert_not Graph.consumable?(:headphone_wired)
  end
end
