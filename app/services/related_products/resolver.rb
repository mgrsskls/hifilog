# frozen_string_literal: true

# Resolves a catalogue entry to the ordered list of targets the "Related Products" block may draw
# candidates from, each carrying the gates its candidates must satisfy. Design: docs/pairing-graph.md.
#
# Ordering (docs §7.5): edges are taken in declaration order within a role -- specialised edges
# before common ones, since what a product needs outranks what it merely tolerates -- then
# interleaved round-robin across the roles the product resolves to, so a multi-function device
# (a DAC/headphone-amp) represents every function it has rather than filling the block from
# whichever role happens to be declared first.
#
# Source-side gates are evaluated here against the product; target-side gates are resolved to
# concrete option ids and handed to Query, which turns them into JSONB conditions.
#
# A gate whose attribute applies to the source's sub categories but holds no value fails CLOSED.
# A gate whose attribute was never attached to those sub categories is INAPPLICABLE and passes:
# the question was never asked, which is not the same as unanswered. This mirrors Completeness,
# where an inapplicable field leaves the denominator rather than scoring as missing.
class RelatedProducts::Resolver
  # Look at this many targets; Query renders the first MAX_GROUPS that yield candidates.
  MAX_TARGETS = 8

  Target = Struct.new(:role, :sub_category_ids, :gates, :same_brand, keyword_init: true)

  # A resolved target-side condition. `option_ids` are ids as stored on products, already
  # translated from the declared i18n keys through the target attribute's own option map.
  Gate = Struct.new(:attribute, :option_ids, :negate, :presence, keyword_init: true)

  def initialize(product:, product_variant: nil)
    @product = product
    @product_variant = product_variant
  end

  def call
    @call ||= interleave(targets_by_role).first(MAX_TARGETS)
  end

  private

  # Variants carry no sub categories and no custom attributes of their own, so both come from
  # the parent product either way.
  def source_sub_category_ids
    @source_sub_category_ids ||= @product.sub_categories.map(&:id)
  end

  def source_sub_category_identifiers
    @source_sub_category_identifiers ||= @product.sub_categories.map(&:identifier)
  end

  def roles
    @roles ||= source_sub_category_identifiers
               .filter_map { |identifier| RelatedProducts::Graph.role_for(identifier) }.uniq
  end

  def targets_by_role
    roles.map { |role| resolve_role(role) }
  end

  def resolve_role(role)
    definition = RelatedProducts::Graph.definition(role)

    edges = specialised_edges(role, definition) + definition.fetch(:edges)
    edges
      .reject { |edge| edge[:enabled] == false }
      .select { |edge| source_gates_pass?(edge) }
      .filter_map { |edge| build_target(edge) }
  end

  # docs §5.1 shape D. When the specialising attribute holds no value the role falls back to
  # its common edges only -- never to a guessed specialisation.
  def specialised_edges(_role, definition)
    specialise = definition[:specialise]
    return [] unless specialise

    value = source_option_keys(specialise[:attribute]).first
    return [] unless value

    specialise[:variants][value.to_sym] || []
  end

  # ---------------------------------------------------------------- source-side evaluation

  def source_gates_pass?(edge)
    presence_passes?(edge) &&
      values_pass?(edge[:source], negate: false) &&
      values_pass?(edge[:source_excludes], negate: true) &&
      match_passes?(edge[:match])
  end

  def presence_passes?(edge)
    label = edge[:source_present]
    return true unless label
    return true unless applicable?(label)

    source_option_keys(label).any?
  end

  def values_pass?(condition, negate:)
    return true unless condition

    condition.all? do |label, keys|
      next true unless applicable?(label)

      held = source_option_keys(label)
      # Fail closed in both directions: unfilled is not the same as known-not-to-match.
      next false if held.empty?

      overlap = held.intersect?(keys.map(&:to_s))
      negate ? !overlap : overlap
    end
  end

  # Cross match (docs §5.1 shape C): the source's value for one attribute -- or the union of
  # several, since an interconnect may terminate in either an input or an output -- must appear
  # among the candidate's values for another.
  def match_passes?(match)
    return true unless match

    labels = Array(match[:source])
    return true if labels.none? { |label| applicable?(label) }

    labels.flat_map { |label| source_option_keys(label) }.any?
  end

  # ------------------------------------------------------------------ target construction

  def build_target(edge)
    sub_category_ids = target_sub_category_ids(edge[:to])
    return nil if sub_category_ids.empty?

    Target.new(
      role: RelatedProducts::Graph.base_role(edge[:to]),
      sub_category_ids:,
      gates: target_gates(edge),
      same_brand: edge[:same_brand] == true
    )
  end

  # A product never suggests gear from a sub category it is itself in: the block offers
  # companions, not alternatives.
  def target_sub_category_ids(target)
    identifiers = RelatedProducts::Graph.sub_categories_for(target) - source_sub_category_identifiers
    CacheService.sub_category_ids_for(identifiers)
  end

  def target_gates(edge)
    gates = []

    implicit = RelatedProducts::Graph.implicit_target_gate(edge[:to])
    gates.concat(resolve_gates(implicit, negate: false)) if implicit
    gates.concat(resolve_gates(edge[:target], negate: false))
    gates.concat(resolve_gates(edge[:target_excludes], negate: true))
    gates.concat(presence_gate(edge[:target_present]))
    gates.concat(match_gate(edge[:match]))
    gates.compact
  end

  # The mirror of source_present: the candidate must hold some value for this attribute. No
  # option ids -- any value passes, none does not.
  def presence_gate(label)
    return [] unless label

    [Gate.new(attribute: label, option_ids: [], negate: false, presence: true)]
  end

  def resolve_gates(condition, negate:)
    return [] unless condition

    condition.filter_map do |label, keys|
      option_ids = option_ids_for(label, keys.map(&:to_s))
      next nil if option_ids.empty?

      Gate.new(attribute: label, option_ids:, negate:, presence: false)
    end
  end

  # The source's held keys become target option ids through the TARGET attribute's own map --
  # ids are per definition and must never be carried across.
  def match_gate(match)
    return [] unless match

    keys = Array(match[:source]).flat_map { |label| source_option_keys(label) }.uniq
    return [] if keys.empty?

    option_ids = option_ids_for(match[:target], keys)
    return [] if option_ids.empty?

    [Gate.new(attribute: match[:target], option_ids:, negate: false, presence: false)]
  end

  # ------------------------------------------------------------------------- attributes

  def definition_for(label)
    attribute_definitions[label]
  end

  def attribute_definitions
    @attribute_definitions ||= CustomAttribute.all_cached.index_by(&:label)
  end

  def applicable?(label)
    definition = definition_for(label)
    return false unless definition

    definition.cached_sub_category_ids.intersect?(source_sub_category_ids)
  end

  # The option KEYS the source product holds for an attribute, translated out of the stored ids.
  def source_option_keys(label)
    definition = definition_for(label)
    return [] unless definition

    stored = @product.custom_attributes&.dig(label)
    return [] if stored.nil?

    options = definition.options || {}
    Array(stored).filter_map { |id| options[id.to_s] }
  end

  def option_ids_for(label, keys)
    definition = definition_for(label)
    return [] unless definition

    (definition.options || {}).filter_map { |id, key| id if keys.include?(key) }
  end

  # ---------------------------------------------------------------------------- ordering

  # Round-robin so every role a product has contributes, then drop repeats of a target already
  # taken from an earlier role.
  def interleave(lists)
    seen = Set.new
    lists.map(&:dup).then do |queues|
      [].tap do |ordered|
        until queues.all?(&:empty?)
          queues.each do |queue|
            target = queue.shift
            next if target.nil?
            next unless seen.add?(target.role)

            ordered << target
          end
        end
      end
    end
  end
end
