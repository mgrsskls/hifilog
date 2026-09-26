# frozen_string_literal: true

class CustomAttribute < ApplicationRecord
  # Every entry needs a `custom_attribute_units` translation -- the views render units with
  # `t()` and no default, exactly like labels. CustomAttributeTest asserts the two lists match,
  # which works here (unlike labels) because both sides are code rather than data.
  #
  # Two units on one definition mean "the same quantity, other system", and the display and
  # filter paths both assume they can convert between them: see UNIT_CONVERSIONS. A unit added
  # here without a counterpart there can only ever be offered on its own.
  VALID_UNITS = %w[
    in cm mm ft m
    lb kg g
    db db_1w_1m db_283v_1m db_mw
    w va v a mv ohm pf
    hz khz
    h mah percent bit um_mn
  ].freeze
  # Named facets of one measurement, sharing that measurement's unit: `w`/`h`/`l` are three
  # dimensions in centimetres, `min`/`max` two ends of one range. The filter treats them the
  # same way -- its own min/max per facet -- so a set of load impedances fits the pattern
  # exactly: amplifier power is quoted per impedance, in watts either way.
  #
  # Speaker and headphone amplifiers keep separate sets rather than one list of six, because
  # `inputs` is also what the product form renders as fields, and an attribute offering both
  # would ask a power amplifier for its output into 300 ohms.
  #
  # Unlike units these need no translation to be *rendered* correctly in more than one place --
  # but every render site calls `t()` with no default, so the same rule applies: nothing goes in
  # here without a `custom_attribute_inputs` entry, and CustomAttributeTest asserts it.
  VALID_INPUTS = %w[
    w h l
    min max
    ohm_2 ohm_4 ohm_8
    ohm_32 ohm_300 ohm_600
  ].freeze

  # The condition under which a number was measured. A third axis beside `units` and `inputs`,
  # and not a variant of either: a unit rescales the number, an input gives one number per facet,
  # a qualifier says what the one number means. ±3 dB and ±6 dB are not two readings of one
  # figure and not two facets a product has at once -- they are two different claims.
  #
  # Always optional. A source often states no condition at all, and an absent qualifier means
  # exactly that. Nothing here is ever assumed as a default, because an assumed condition is
  # invented data.
  #
  # Each entry needs a `custom_attribute_qualifiers` translation, for the same reason units and
  # inputs do: every render site calls `t()` with no default. CustomAttributeTest asserts it.
  #
  # One definition offers values of ONE dimension, because an entry holds one qualifier. A list
  # mixing tolerance with "both channels driven" could not be stored: both are true of one
  # figure. The order inside a group is the order the filter offers, from the tightest claim to
  # the loosest, which is what a later "or better" filter would read.
  VALID_QUALIFIERS = %w[
    plus_minus_1_db plus_minus_2_db plus_minus_3_db plus_minus_6_db
    minus_3_db minus_6_db minus_10_db
    thd_0_1_percent thd_1_percent thd_10_percent
    distance_1m distance_2m
    drive_1w_1m drive_283v_1m
  ].freeze

  # The groups that the product page, the product form and the filter use to show custom
  # attributes. The order of this list is the order of the groups. Inside a group,
  # `display_position` sets the order. See docs/custom-attributes.md, "Display order".
  #
  # Each entry needs a `custom_attribute_groups` translation, because the product page and the
  # product form show the group name with `t()` and no default. CustomAttributeTest asserts it.
  DISPLAY_GROUPS = %w[
    design
    performance
    connectivity
    physical
  ].freeze

  # Imperial unit => [the metric unit it is stored and compared in, multiplier].
  #
  # Filtering compares a submitted range against `custom_attributes -> label ->> 'unit'` after
  # normalising both sides through this table, so the canonical unit is also the one a value
  # has to be *stored* in to be findable at all. That is why the table is deliberately short:
  # a unit only belongs here once something converts to it, and a definition may only offer
  # two units when those two are a pair listed here.
  #
  # `mm` is therefore not paired with `in`: `in` already canonicalises to `cm`, so a definition
  # offering millimetres and inches would store two incompatible spellings of the same
  # measurement and match neither filter. Millimetre attributes offer millimetres only.
  #
  # Two readings of one figure that no factor relates are not units at all. dB@1W/1m and
  # dB@2.83V/1m were spelled as units here until VALID_QUALIFIERS existed; they are one unit, dB,
  # measured under two conditions. A second unit that cannot convert belongs in `qualifiers`.
  UNIT_CONVERSIONS = {
    'in' => ['cm', 2.54],
    'ft' => ['m', 0.3048],
    'lb' => ['kg', 0.45359237]
  }.freeze

  # Both directions of UNIT_CONVERSIONS, as unit => [other unit, multiplier], so a display can
  # show "1.2 kg / 2.65 lb" from either side without a second table drifting out of step with
  # the first. It did drift: the show page and the changelog each carried their own pound
  # factor of 0.454 while filtering used 0.45359237.
  UNIT_EQUIVALENTS = UNIT_CONVERSIONS.each_with_object({}) do |(from, (to, factor)), acc|
    acc[from] = [to, factor]
    acc[to] = [from, 1.0 / factor]
  end.freeze

  before_destroy :refuse_destroy_while_graph_references_label
  before_destroy :remember_sub_category_ids_for_completeness
  # The admin form posts { sub_category_id => [option ids] }. Applied after save rather than on
  # assignment, because a subcategory ticked in the same submit has no join row to write to
  # until the HABTM assignment has been persisted.
  after_save :persist_option_scopes, if: -> { @option_scopes.present? }
  # after_commit ensures the DB transaction is finished before we clear cache
  after_commit :clear_cache
  # Only `highlighted` and sub_categories affect Product#applicable_highlighted_attributes, so
  # only those two changes need to fan out to every product they touch. The fan-out runs in
  # SubCategoryCompletenessJob, one job per sub category, not in the admin request (see
  # Product.recalculate_completeness_for_sub_categories_later). A pure options/units/label edit
  # does not fan out.
  after_commit :recompute_products_completeness_for_highlighted_change, on: [:create, :update]
  after_commit :recompute_products_completeness_after_destroy, on: :destroy

  attr_writer :option_scopes

  # after_add / after_remove: a sub_categories reassignment writes the join table directly (see
  # `clear_cache` below for why -- the same reasoning applies to completeness), so it needs its
  # own hook rather than relying on the after_commit above to catch it.
  has_and_belongs_to_many :sub_categories,
                          after_add: :recompute_products_completeness_for_sub_category,
                          after_remove: :recompute_products_completeness_for_sub_category
  enum :input_type, {
    number: 'number',
    option: 'option',
    options: 'options',
    boolean: 'boolean'
  }, suffix: true

  validates :label, presence: true, uniqueness: true
  # `presence: true` cannot express "a boolean that must be answered": `false.present?` is
  # false, so it rejected every attribute that is not a key spec -- 13 of the 30 that exist.
  # Those rows predate the validation, which is why the catalogue is full of values the model
  # would now refuse to save: any of them opened in ActiveAdmin could only be saved by ticking
  # Highlighted. `inclusion` is the idiom that separates "false" from "unanswered".
  validates :highlighted, inclusion: { in: [true, false] }
  validates :display_group, presence: true, inclusion: { in: DISPLAY_GROUPS }
  validates :display_position, presence: true, numericality: { only_integer: true }
  validate :units_must_be_valid
  validate :inputs_must_be_valid
  validate :qualifiers_must_be_valid
  validate :label_must_be_translated
  validate :option_values_must_be_translated
  # RelatedProducts::Graph names attributes and option keys as Ruby constants, so the database
  # cannot enforce the reference. These three refuse the edits that would break it -- silently,
  # were they allowed: a renamed label leaves a gate naming nothing, a removed option key leaves
  # one that can never match. The graph is code, so the fix is always to change the graph first
  # and deploy; the guard lifts by itself once the reference is gone.
  validate :graph_must_not_lose_its_label, on: :update
  validate :graph_must_not_lose_an_option_key, on: :update

  before_validation do
    self.units = units.compact_blank if units.is_a?(Array)
    self.inputs = inputs.compact_blank if inputs.is_a?(Array)
    self.qualifiers = qualifiers.compact_blank if qualifiers.is_a?(Array)
  end

  # Exactly one shape of extra configuration applies per input type. Anything left over
  # from a previous type is not merely unused: the product form branches on `options`
  # first and `inputs` second without consulting `input_type` at all, so a boolean
  # attribute still carrying old options would render radio buttons. Switching type
  # clears what no longer applies instead of leaving that trap behind — before
  # validation, so values that are inapplicable anyway can't fail validation either.
  before_validation do
    if input_type.present?
      self.options = nil unless option_input_type? || options_input_type?

      unless number_input_type?
        self.units = []
        self.inputs = []
        self.qualifiers = []
      end
    end
  end

  before_save do
    if options.present?
      self.options = JSON.parse(options) if options.is_a?(String)
    else
      self.options = nil
    end
  end

  # The unit a value in `unit` is stored and compared in. Unconvertible units are their own
  # canonical form, so callers never have to ask whether a unit is convertible first.
  def self.canonical_unit(unit)
    UNIT_CONVERSIONS.dig(unit.to_s, 0) || unit
  end

  # `value` expressed in canonical_unit(unit). nil passes through so a half-filled range
  # ("under 3 kg", no minimum) stays half-filled rather than becoming 0.
  def self.in_canonical_unit(value, unit)
    return value if value.nil?

    factor = UNIT_CONVERSIONS.dig(unit.to_s, 1)
    factor ? value * factor : value
  end

  # The translated condition of one stored entry, or nil when the entry states none.
  #
  # One method for all five display sites -- the characteristics list, the product card, the
  # changelog, the admin activity list and the import candidate view -- because a qualifier that
  # is rendered in four of them and forgotten in the fifth is the failure that is hardest to see:
  # the changelog would then show the same text before and after a change of the condition alone.
  #
  # `t` without a default, like every other custom attribute translation, so a key with nothing
  # behind it is loud instead of silent.
  def self.qualifier_label(entry)
    return unless entry.is_a?(Hash)

    key = entry['qualifier'].presence || entry[:qualifier].presence
    return if key.blank?

    I18n.t("custom_attribute_qualifiers.#{key}")
  end

  # [other unit, multiplier] when a unit has a counterpart in the other system, otherwise nil.
  # Display sites use it to render both readings; nil means there is only one reading to show.
  def self.equivalent_unit(unit)
    UNIT_EQUIVALENTS[unit.to_s]
  end

  # Removes a `unit` or `qualifier` that the definition does not offer, and a blank one.
  #
  # Both are strings the caller chooses, and nothing in the database constrains them. Three write
  # paths can put a wrong one there: the product form permits an open hash, so a stale or crafted
  # submission can name anything; ImportPromotion copies a candidate's specs verbatim, and a
  # candidate extracted before a definition changed still carries the old unit; and the console.
  #
  # A wrong value is invisible in the data and surfaces only as a missing translation on the
  # product page, or as a figure no filter can reach -- filtering compares the stored unit string
  # against what the definition offers.
  #
  # Blank goes too. The product form's condition control offers "not stated" as an empty option, so
  # that value arrives on every submit where the condition is unknown; stored, `? 'qualifier'` would
  # report a condition that is not there, and every reader would need a third case.
  #
  # Runs before normalize_units, so a unit the definition does not offer is dropped rather than
  # used as the basis of a conversion.
  def self.prune_unsupported_keys(values)
    return values if values.blank?

    index = all_cached.index_by(&:label)

    values.to_h do |label, entry|
      definition = index[label]
      next [label, entry] unless definition&.number_input_type?
      next [label, entry] unless entry.is_a?(Hash)

      [label, definition.pruned_entry(entry)]
    end
  end

  # One entry of that hash, with the keys the definition cannot account for removed.
  #
  # The two keys are treated differently, because "declares none" means different things:
  #
  #   * A definition with an empty `units` says nothing about units, and the filter says nothing
  #     either -- it applies a unit predicate only `if custom_attribute[:units].present?`. A stored
  #     unit is therefore not unreachable, so removing it would accomplish nothing and would break
  #     the normalisation that runs next: `normalize_units` needs the unit to convert from.
  #   * A definition with an empty `qualifiers` asks no question about the condition, so a stored
  #     one is not an answer to anything. It still renders -- `qualifier_label` reads the entry,
  #     not the definition -- so a leftover condition would print on the product page under a
  #     definition whose form no longer offers it.
  #
  # A blank value of either goes in both cases: it is neither a value nor absent, and every reader
  # would need a third case for it.
  def pruned_entry(entry)
    entry = entry.to_unsafe_h if entry.respond_to?(:to_unsafe_h)
    entry = entry.to_h.stringify_keys

    entry.delete('unit') if entry['unit'].blank? || (units.present? && units.exclude?(entry['unit']))
    entry.delete('qualifier') unless qualifier?(entry['qualifier'])

    entry
  end

  # Rewrites a product's whole `custom_attributes` hash so every numeric entry is expressed in
  # its canonical unit.
  #
  # Filtering compares a submitted range against the stored `unit` string after normalising
  # the range to the metric side of a pair, so a value stored as `{value: 2, unit: "lb"}` is
  # not merely awkward -- it is unreachable. No weight filter can ever return it, in either
  # unit, because nothing converts on read. Normalising on write makes "stored unit" and
  # "canonical unit" the same thing everywhere downstream, which is what the filter already
  # assumed.
  #
  # Idempotent: a canonical unit converts to itself, so re-saving an already normalised
  # product is a no-op rather than a repeated multiplication.
  def self.normalize_units(values)
    return values if values.blank?

    index = all_cached.index_by(&:label)

    values.to_h do |label, entry|
      definition = index[label]

      [label, definition ? definition.normalized_entry(entry) : entry]
    end
  end

  # One entry of that hash. Anything this does not recognise -- a non-numeric attribute, a
  # missing or already-canonical unit, a value that is not a number -- is passed through
  # untouched rather than guessed at.
  def normalized_entry(entry)
    return entry unless number_input_type?
    return entry unless entry.is_a?(Hash)

    unit = entry['unit'].presence || entry[:unit].presence
    return entry if unit.blank?

    canonical = self.class.canonical_unit(unit)
    return entry if canonical == unit

    converted = convert_entry_value(entry['value'] || entry[:value], unit)
    return entry if converted.nil?

    entry.merge('value' => converted, 'unit' => canonical)
  end

  # The definitions in display order: first by the position of the group in DISPLAY_GROUPS, then
  # by `display_position`. The label is the last tie-breaker, so that the order is stable when two
  # definitions have the same position.
  #
  # The sort runs in Ruby and not in SQL. The group order is in code, so SQL would need a CASE
  # expression. There are only a few definitions, and all callers have them in memory already
  # (all_cached, or the definitions of one product or one sub category).
  def self.sort_for_display(definitions)
    definitions.sort_by(&:display_sort_key)
  end

  # The same order, as [[group, [definitions]], ...]. Groups without definitions are not in the
  # result, so a view does not show an empty heading.
  def self.group_for_display(definitions)
    sort_for_display(definitions).chunk_while { |a, b| a.display_group == b.display_group }
                                 .map { |chunk| [chunk.first.display_group, chunk] }
  end

  def display_sort_key
    [DISPLAY_GROUPS.index(display_group) || DISPLAY_GROUPS.size, display_position.to_i, label.to_s]
  end

  def display_group_name
    I18n.t("custom_attribute_groups.#{display_group}")
  end

  def self.all_cached
    Rails.cache.fetch(all_cached_key) do
      all.to_a # .to_a executes the query and stores the array
    end
  end

  # The cache holds complete records, so the key contains the column names. A migration that adds
  # a column writes with SQL and does not run clear_cache. Records that were cached before the
  # migration do not have the new column and return nil for it. With the columns in the key, the
  # first read after a schema change goes to a new entry. This is also true in production, where
  # the cache stays through a deploy and old dynos can fill the old key during the release phase.
  def self.all_cached_key
    "all_custom_attributes/#{Digest::SHA256.hexdigest(column_names.join(','))[0, 12]}"
  end

  # { attribute_id => { sub_category_id => ["1", "2"] } }, where an empty array means every
  # option of that attribute applies in that subcategory.
  #
  # One pluck for the whole join table, cached as plain data rather than as records: the product
  # form renders every attribute on every load and would otherwise ask each one for its
  # subcategories separately. It answers both questions at once -- which subcategories an
  # attribute applies to (the keys) and which options apply in each (the values) -- so the form
  # reads it instead of `sub_category_ids`.
  def self.sub_category_scopes_cached
    Rails.cache.fetch('custom_attribute_sub_category_scopes') do
      CustomAttributeSubCategory
        .pluck(:custom_attribute_id, :sub_category_id, :option_ids)
        .each_with_object({}) do |(attribute_id, sub_category_id, ids), acc|
        (acc[attribute_id] ||= {})[sub_category_id] =
          ids
      end
    end
  end

  def self.clear_sub_category_scope_cache
    Rails.cache.delete('custom_attribute_sub_category_scopes')
  end

  # The subcategories this attribute applies to, from the cached map rather than a query per
  # attribute.
  def cached_sub_category_ids
    self.class.sub_category_scopes_cached.fetch(id, {}).keys
  end

  # The options to offer for something sitting in `sub_category_ids`.
  #
  # A union, not an intersection: a product in two subcategories is genuinely both, so an option
  # either subcategory offers is a legitimate answer. An empty subset means "all of them", so
  # one unscoped subcategory widens the union back to the full list -- which is what makes this
  # safe to leave unset everywhere it does not matter.
  #
  # `select` rather than `slice`, so the definition's own ordering survives.
  def options_for(sub_category_ids)
    return options if options.blank?

    scopes = self.class.sub_category_scopes_cached[id]
    return options if scopes.blank?

    subsets = Array(sub_category_ids).map(&:to_i).filter_map { |sub_category_id| scopes[sub_category_id] }
    return options if subsets.empty? || subsets.any?(&:empty?)

    allowed = subsets.flatten.uniq

    # Not slice(*allowed): slice orders its result by the argument list, not by `options`'
    # own key order, so it would return the scoping order (or, unioned, an arbitrary one)
    # instead of the curated order the definition was written in.
    # rubocop:disable Style/HashSlice
    options.select { |key, _| allowed.include?(key) }
    # rubocop:enable Style/HashSlice
  end

  # The subcategories in which a single option is offered, for the product form to serialise
  # next to that option. A subcategory with no subset offers everything, so it counts.
  def sub_category_ids_for_option(option_id)
    self.class.sub_category_scopes_cached.fetch(id, {}).filter_map do |sub_category_id, ids|
      sub_category_id if ids.empty? || ids.include?(option_id.to_s)
    end
  end

  # True when at least one subcategory narrows this attribute's options, i.e. when the form has
  # any reason to filter them client-side.
  def option_scoped?
    self.class.sub_category_scopes_cached.fetch(id, {}).any? { |_, ids| ids.present? }
  end

  # Every i18n key that may be used as an option value, as [key, translated label]
  # pairs. Feeds the datalist behind the admin option editor so an admin picks from
  # what the locale file already defines instead of guessing a key.
  def self.available_option_keys
    translations = I18n.t('custom_attributes', default: {})
    return [] unless translations.is_a?(Hash)

    translations.map { |key, label| [key.to_s, label.to_s] }.sort_by(&:last)
  end

  # The admin form posts options as an ordered list of { key:, value: } rows. `key` is
  # the stable id products store in their own `custom_attributes` hash; `value` is the
  # i18n key rendered to users. Keeping the two apart means renaming a label never
  # renumbers anything, so no product silently changes meaning.
  #
  # Ids are only ever handed out above the highest one seen — including ids that were
  # just deleted in this same submit — so a freed id is never reused by a new option.
  def options_attributes=(rows)
    rows = rows.values if rows.is_a?(Hash)

    pairs = Array(rows).filter_map do |row|
      row = row.to_unsafe_h if row.respond_to?(:to_unsafe_h)
      value = row[:value] || row['value']
      next if value.blank?

      [(row[:key] || row['key']).to_s, value.to_s.strip]
    end

    self.options = pairs.any? ? build_options_hash(pairs) : nil
  end

  # How many products hold a value for each attribute, as { "weight" => 12 }.
  #
  # One pass over products rather than one query per attribute: `custom_attributes ? :label`
  # would be index-assisted for a literal label, but not for a column reference, so asking per
  # attribute would scan the table once per attribute instead of once in total. Only the admin
  # index calls this, and it is the one place that wants the answer for every attribute at once.
  def self.product_usage_counts
    connection.select_rows(<<~SQL.squish).to_h { |label, total| [label, total.to_i] }
      SELECT key, COUNT(*)
      FROM products, LATERAL jsonb_object_keys(products.custom_attributes) AS key
      WHERE products.custom_attributes IS NOT NULL
      GROUP BY key
    SQL
  end

  # How many products currently reference each option id, as { "1" => 12 }.
  #
  # One aggregate query rather than one COUNT per option, and the WHERE narrows through
  # the GIN index on products.custom_attributes (`?` is a jsonb_ops-indexable operator)
  # before any row is expanded, so this stays cheap as the catalog grows. Only the admin
  # form asks for it.
  def option_usage_counts
    return {} if label.blank? || options.blank?
    return {} unless option_input_type? || options_input_type?

    self.class.connection.select_rows(usage_counts_sql).to_h do |option_id, total|
      [option_id.to_s, total.to_i]
    end
  end

  # A label is not just an identifier, it is an i18n key: every surface that renders an
  # attribute -- the product form, the filter sidebar, the spec list, the admin subcategory
  # page -- calls `t("custom_attribute_labels.#{label}")` with no default, so a label with no
  # translation behind it does not degrade, it prints "translation missing" to the user.
  #
  # Nothing else can catch that. The values are data rows created through ActiveAdmin, so a
  # test cannot enumerate what production holds; the only moment the two can be compared is
  # the moment the row is written. This does mean the translation has to be deployed before
  # the attribute is created, which is the same order `available_option_keys` already imposes
  # on option values.
  def graph_must_not_lose_its_label
    return unless label_changed?
    return unless graph_gate_attributes.include?(label_was)

    errors.add(
      :label,
      "cannot be renamed from \"#{label_was}\" while RelatedProducts::Graph gates on it. " \
      'Change the gate in app/services/related_products/graph.rb first, then rename here.'
    )
  end

  def graph_must_not_lose_an_option_key
    return unless options_changed?

    referenced = RelatedProducts::Graph.referenced_option_keys[label_was.presence || label]
    return if referenced.blank?

    removed = (referenced & Array((options_was || {}).values)) - Array((options || {}).values)
    return if removed.empty?

    errors.add(
      :options,
      "cannot drop #{removed.join(', ')} while RelatedProducts::Graph references " \
      "#{'it'.pluralize(removed.size)}. A gate naming an option the definition no longer offers " \
      'can never match. Remove the gate in app/services/related_products/graph.rb first.'
    )
  end

  def refuse_destroy_while_graph_references_label
    return unless graph_gate_attributes.include?(label)

    errors.add(
      :base,
      "#{label} cannot be deleted while RelatedProducts::Graph gates on it. Remove the gate in " \
      'app/services/related_products/graph.rb first.'
    )
    throw(:abort)
  end

  def graph_gate_attributes
    RelatedProducts::Graph.gate_attributes
  end

  def label_must_be_translated
    return if label.blank?
    return if I18n.exists?("custom_attribute_labels.#{label}")

    errors.add(:label, "has no translation: add `#{label}` under `custom_attribute_labels` " \
                       'in config/locales/en.yml first')
  end

  # The same guarantee one level down. The admin option editor offers a datalist of existing
  # keys, but a datalist is a suggestion rather than a constraint, and a typo here is worse
  # than a missing label: products store the option *id*, so the broken key is invisible in
  # the data and only surfaces as a missing translation on every product that chose it.
  def option_values_must_be_translated
    missing = parsed_options.values.map(&:to_s).uniq.reject do |value|
      value.blank? || I18n.exists?("custom_attributes.#{value}")
    end
    return if missing.empty?

    errors.add(:options, 'have no translation under `custom_attributes` in ' \
                         "config/locales/en.yml: #{missing.join(', ')}")
  end

  def units_must_be_valid
    return if units.blank?

    cleaned_units = units.compact_blank
    invalid = cleaned_units - VALID_UNITS

    errors.add(:units, "contain invalid values: #{invalid.join(', ')}") if invalid.any?
  end

  def inputs_must_be_valid
    return if inputs.blank?

    cleaned_inputs = inputs.compact_blank
    invalid = cleaned_inputs - VALID_INPUTS

    # :inputs, not :units. The admin form renders each error beside its own field, so this
    # reported a bad input against the units checkboxes -- pointing at the group that was fine.
    errors.add(:inputs, "contain invalid values: #{invalid.join(', ')}") if invalid.any?
  end

  def qualifiers_must_be_valid
    return if qualifiers.blank?

    invalid = qualifiers.compact_blank - VALID_QUALIFIERS

    errors.add(:qualifiers, "contain invalid values: #{invalid.join(', ')}") if invalid.any?
  end

  # True when this definition records a measurement condition at all. Every surface that renders
  # or filters a qualifier asks this first, so none of them repeats the `number` test.
  def qualified?
    number_input_type? && qualifiers.present?
  end

  # Whether `key` is a condition this definition offers. The write path drops anything else, the
  # way an unknown label is dropped: a value no definition knows can be displayed, filtered or
  # scored by nothing.
  def qualifier?(key)
    key.present? && qualifiers.include?(key.to_s)
  end

  # simplecov:disable
  def self.ransackable_attributes(_auth_object = nil)
    # input_type and highlighted are here so the admin index can sort on those columns; Ransack
    # refuses any attribute not on this list, and a column it refuses is one that silently does
    # nothing when clicked.
    %w[
      sub_categories
      sub_categories_id
      label
      input_type
      highlighted
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # simplecov:enable

  private

  # A `number` attribute holds either a bare number or, when it declares `inputs`, one number
  # per input. Rounding keeps the stored JSON readable and cannot lose anything a spec sheet
  # carries -- display already truncates to four places.
  #
  # Eight rather than six, because this precision is also what the product form's unit toggle
  # round-trips through: at six, 2 lb stores as 0.907185 kg and toggling back reads 2.000001,
  # since 0.907185 kg genuinely is 2.000001 lb. Eight keeps the exact conversion, so the
  # number a contributor typed is the number they see again. entity_form.js rounds to match.
  #
  # All inputs share one `unit`, so a multi-input value is converted all-or-nothing: if any
  # input is not a number, none of them are, and nil bubbles up to normalized_entry so the
  # entry -- unit included -- is left exactly as it arrived rather than half-converted under
  # a unit that no longer matches the input that couldn't be converted.
  def convert_entry_value(value, unit)
    case value
    when Hash, ActionController::Parameters
      numbers = value.to_h.transform_values { |number| numeric(number) }
      return nil if numbers.empty? || numbers.value?(nil)

      numbers.transform_values { |number| self.class.in_canonical_unit(number, unit).round(8) }
    else
      number = numeric(value)

      number ? self.class.in_canonical_unit(number, unit).round(8) : nil
    end
  end

  def numeric(value)
    return value if value.is_a?(Numeric)

    Float(value.to_s, exception: false)
  end

  # Writes what the admin ticked onto the join rows.
  #
  # Every option ticked is stored as `[]`, not as the full list. The two mean the same thing
  # today, but only the empty array keeps meaning "all of them" after a new option is added --
  # so a subcategory nobody deliberately narrowed goes on offering everything, which is the rule
  # the whole feature rests on. Saving the full list instead would quietly freeze that
  # subcategory at today's options.
  #
  # A subcategory absent from the params is left alone rather than cleared: it was not on the
  # form, which is the case for one ticked in this same submit.
  def persist_option_scopes
    submitted = @option_scopes
    @option_scopes = nil

    known = options&.keys || []

    CustomAttributeSubCategory.where(custom_attribute_id: id).find_each do |link|
      ids = submitted[link.sub_category_id.to_s]
      next if ids.nil?

      ids = Array(ids).map(&:to_s).compact_blank & known
      ids = [] if ids.to_set == known.to_set

      link.update!(option_ids: ids) unless link.option_ids.to_set == ids.to_set
    end
  end

  # `options` is only guaranteed to be a Hash after before_save; validation can still see the
  # raw JSON string an assignment passed in. Anything that does not parse into a Hash has no
  # option values to check and is left to the column's own casting to reject.
  def parsed_options
    return options if options.is_a?(Hash)
    return {} unless options.is_a?(String) && options.present?

    parsed = JSON.parse(options)
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end

  def build_options_hash(pairs)
    known = (options.is_a?(Hash) ? options.keys : []) + pairs.map(&:first)
    next_id = known.filter_map { |key| key.to_s[/\A\d+\z/]&.to_i }.max.to_i

    pairs.each_with_object({}) do |(key, value), acc|
      key = (next_id += 1).to_s if key.blank? || acc.key?(key)
      acc[key] = value
    end
  end

  # An `option` attribute stores a bare id per product, an `options` (plural) attribute
  # stores an array of them, so the two need different shapes of the same count. Both
  # lead with `?`, the only condition here the GIN index can serve; the array form adds
  # a jsonb_typeof filter so a product holding a scalar where an array is expected is
  # skipped rather than aborting the whole query.
  def usage_counts_sql
    if options_input_type?
      sanitize_sql(
        ['SELECT o.option_id, COUNT(*) FROM products p, ' \
         'LATERAL jsonb_array_elements_text(p.custom_attributes -> :label) AS o(option_id) ' \
         "WHERE p.custom_attributes ? :label AND jsonb_typeof(p.custom_attributes -> :label) = 'array' " \
         'GROUP BY o.option_id', { label: label }]
      )
    else
      sanitize_sql(
        ['SELECT p.custom_attributes ->> :label AS option_id, COUNT(*) FROM products p ' \
         'WHERE p.custom_attributes ? :label GROUP BY 1', { label: label }]
      )
    end
  end

  def sanitize_sql(statement)
    self.class.send(:sanitize_sql_array, statement)
  end

  # Both maps, because a HABTM write goes through this record rather than through
  # CustomAttributeSubCategory: `attribute.sub_categories = [...]` inserts and deletes join rows
  # directly, so the join model's own callback never runs for them.
  def clear_cache
    Rails.cache.delete(self.class.all_cached_key)
    self.class.clear_sub_category_scope_cache
  end

  def recompute_products_completeness_for_sub_category(sub_category)
    return unless highlighted?

    Product.recalculate_completeness_for_sub_categories_later([sub_category.id])
  end

  def recompute_products_completeness_for_highlighted_change
    return unless saved_change_to_highlighted?

    Product.recalculate_completeness_for_sub_categories_later(sub_category_ids)
  end

  def remember_sub_category_ids_for_completeness
    @sub_category_ids_before_destroy = sub_category_ids
  end

  def recompute_products_completeness_after_destroy
    return unless highlighted?

    Product.recalculate_completeness_for_sub_categories_later(@sub_category_ids_before_destroy)
  end
end
