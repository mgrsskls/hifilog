# frozen_string_literal: true

# Verifies the authored pairing graph (app/services/related_products/graph.rb) against a real
# catalogue. The graph is constants referring to sub category identifiers, custom attribute
# labels and option keys that all live in the database, and a stale reference fails quietly: a
# missing identifier silently empties a group, an option key the definition no longer offers
# silently closes a gate, a sub category nobody gave a role never shows Related Products at all.
# None of that is visible in the test suite, whose fixture catalogue holds a handful of rows.
#
# Run via `bin/rails related_products:check` against staging or production after adding a sub
# category or editing a custom attribute.
class RelatedProducts::GraphCheck
  Result = Struct.new(:problems, :notes, keyword_init: true)

  def self.call
    new.call
  end

  def call
    problems = [
      orphan_problem,
      unknown_identifier_problem,
      missing_attribute_problem,
      *option_key_problems
    ].compact
    notes = []

    graph::ROLES.each do |role, definition|
      check_specialise(role, definition, problems)

      note = inapplicable_note(role, definition)
      notes << note if note
    end

    Result.new(problems: problems, notes: notes)
  end

  private

  def check_specialise(role, definition, problems)
    specialise = definition[:specialise]
    return unless specialise

    attribute = definitions[specialise[:attribute]]
    if attribute.nil?
      problems << "#{role} specialises on #{specialise[:attribute]}, which has no definition"
      return
    end

    missing = specialise[:variants].keys.map(&:to_s) - (attribute.options || {}).values
    return unless missing.any?

    problems << "#{specialise[:attribute]} no longer offers #{missing.join(', ')}, so #{role} cannot specialise"
  end

  def orphan_problem
    orphans = SubCategory.order(:identifier).pluck(:identifier)
                         .reject { |identifier| graph.role_for(identifier) }
    return if orphans.empty?

    "sub categories with no role (Related Products will never appear on them): #{orphans.join(', ')}"
  end

  def unknown_identifier_problem
    unknown = graph::SUB_CATEGORY_ROLES.keys - SubCategory.pluck(:identifier)
    return if unknown.empty?

    "graph declares sub category identifiers that do not exist: #{unknown.join(', ')}"
  end

  def missing_attribute_problem
    missing_attributes = graph.gate_attributes - definitions.keys
    return if missing_attributes.empty?

    "gates name custom attributes with no definition: #{missing_attributes.join(', ')}"
  end

  def option_key_problems
    graph.gate_option_keys.filter_map do |label, keys|
      definition = definitions[label]
      next unless definition

      missing = keys - (definition.options || {}).values
      next if missing.empty?

      "#{label} no longer offers #{missing.join(', ')} -- those gates can never match"
    end
  end

  # Not a failure: an attribute a gate reads but which was never attached to that role's sub
  # categories is inapplicable, and an inapplicable gate passes rather than closing (docs §5.4).
  # Worth reporting, because it is also what a mis-scoped attribute looks like.
  #
  # Checked for every role, not only the ones that specialise, and ignoring disabled edges --
  # see source_labels. Both were bugs: the note fired for four loudspeaker roles whose only
  # source-side read was the match on a disabled interconnect edge, while the same condition on
  # cd_player, tuner, power_amp, integrated, headphone_amp and switch_box went unreported because
  # those roles do not specialise.
  def inapplicable_note(role, definition)
    attached = definition[:sub_categories].filter_map { |identifier| identifier_ids[identifier] }
    return if attached.empty?

    inapplicable = source_labels(definition).reject do |label|
      definitions[label]&.cached_sub_category_ids.to_a.intersect?(attached)
    end
    return if inapplicable.empty?

    "#{role} reads #{inapplicable.join(', ')}, not attached to its sub categories"
  end

  def source_labels(definition)
    graph.declared_edges(definition)
         .reject { |edge| edge[:enabled] == false }
         .flat_map do |edge|
      labels = graph::CONDITION_KEYS.filter_map do |key|
        edge[key]&.keys if [:source, :source_excludes].include?(key)
      end.flatten
      labels << edge[:source_present] if edge[:source_present]
      labels.concat(Array(edge[:match][:source])) if edge[:match]
      labels
    end.uniq
  end

  def definitions
    @definitions ||= CustomAttribute.all.index_by(&:label)
  end

  # One pluck rather than a find_by per role.
  def identifier_ids
    @identifier_ids ||= SubCategory.pluck(:identifier, :id).to_h
  end

  def graph
    RelatedProducts::Graph
  end
end
