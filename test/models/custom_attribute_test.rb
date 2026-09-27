# frozen_string_literal: true

require 'test_helper'

class CustomAttributeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @sub_category = sub_categories(:one)
  end

  test 'requires label presence' do
    record = CustomAttribute.new(highlighted: true, label: '')
    assert_not record.valid?
    assert record.errors.attribute_names.include?(:label)
  end

  test 'requires label uniqueness' do
    dup = CustomAttribute.new(
      highlighted: false,
      label: custom_attributes(:one).label,
      input_type: 'option'
    )

    dup.sub_categories << @sub_category
    assert_not dup.valid?
    assert dup.errors.attribute_names.include?(:label)
  end

  test 'requires highlighted to be answered' do
    record = CustomAttribute.new(
      label: 'nominal_impedance',
      input_type: 'boolean'
    )

    record.highlighted = nil

    assert_not record.valid?
    assert record.errors.attribute_names.include?(:highlighted)
  end

  # The regression the old `presence: true` was: false is a real answer, not a blank one, and
  # rejecting it made every attribute that is not a key spec unsaveable -- including through
  # ActiveAdmin, where 13 of the 30 existing definitions could only be saved by ticking
  # Highlighted.
  test 'highlighted false is a valid answer' do
    record = CustomAttribute.new(
      label: 'nominal_impedance',
      highlighted: false,
      display_group: 'design',
      display_position: 10,
      input_type: 'boolean'
    )

    record.sub_categories << @sub_category

    assert record.valid?, record.errors.full_messages.to_sentence
  end

  # Every render site calls t("custom_attribute_labels.#{label}") without a default, so an
  # untranslated label reaches the user as "translation missing" rather than degrading. These
  # rows are admin-created data, so creation time is the only moment the check can happen.
  test 'a label with no custom_attribute_labels translation is rejected' do
    record = CustomAttribute.new(
      label: 'no_such_label_in_the_locale_file',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'boolean'
    )

    record.sub_categories << @sub_category

    assert_not record.valid?
    assert_includes record.errors[:label].join(' '), 'has no translation'
  end

  test 'every label the locale file defines is accepted' do
    I18n.t('custom_attribute_labels').each_key do |label|
      record = CustomAttribute.new(label: label.to_s, highlighted: true, input_type: 'boolean')
      record.valid?

      assert_empty record.errors[:label].grep(/has no translation/),
                   "#{label} should be accepted but was not"
    end
  end

  # The reverse direction, which is what caught `weight`, `dimensions` and `assembly`
  # rendering as raw keys: a locale entry with no attribute behind it is harmless, an
  # attribute with no locale entry is not. Fixtures stand in for the real definitions here.
  test 'no persisted attribute is missing its translation' do
    untranslated = CustomAttribute.all.reject { |record| I18n.exists?("custom_attribute_labels.#{record.label}") }

    assert_empty untranslated.map(&:label)
  end

  test 'an option value with no custom_attributes translation is rejected' do
    record = CustomAttribute.new(
      label: 'nominal_impedance',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'option',
      options: { '1' => 'solid_state', '2' => 'not_a_translated_option' }
    )

    record.sub_categories << @sub_category

    assert_not record.valid?
    assert_includes record.errors[:options].join(' '), 'not_a_translated_option'
    assert_not_includes record.errors[:options].join(' '), 'solid_state'
  end

  test 'option values are still checked when options arrive as a JSON string' do
    record = CustomAttribute.new(
      label: 'nominal_impedance',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'option',
      options: { '1' => 'not_a_translated_option' }.to_json
    )

    assert_not record.valid?
    assert_includes record.errors[:options].join(' '), 'not_a_translated_option'
  end

  # Clearing options on a type switch happens before validation, so a boolean attribute is
  # never rejected for options it is in the process of discarding.
  test 'options left over from a previous input type do not fail validation' do
    record = custom_attributes(:one)
    record.options = { '1' => 'not_a_translated_option' }
    record.input_type = 'boolean'

    assert record.valid?, record.errors.full_messages.to_sentence
  end

  # Units and inputs are rendered by `t()` with no default, exactly like labels -- but both are
  # closed constants rather than admin-created rows, so unlike labels a test can enumerate them
  # and this needs no runtime validation.
  test 'every valid unit has a custom_attribute_units translation' do
    untranslated = CustomAttribute::VALID_UNITS.reject do |unit|
      I18n.exists?("custom_attribute_units.#{unit}")
    end

    assert_empty untranslated
  end

  test 'every valid input has a custom_attribute_inputs translation' do
    untranslated = CustomAttribute::VALID_INPUTS.reject do |input|
      I18n.exists?("custom_attribute_inputs.#{input}")
    end

    assert_empty untranslated
  end

  test 'every display group has a custom_attribute_groups translation' do
    untranslated = CustomAttribute::DISPLAY_GROUPS.reject do |group|
      I18n.exists?("custom_attribute_groups.#{group}")
    end

    assert_empty untranslated
  end

  test 'requires a known display group and an integer display position' do
    record = custom_attributes(:one)
    record.display_group = 'acoustics'
    record.display_position = nil

    assert_not record.valid?
    assert_includes record.errors.attribute_names, :display_group
    assert_includes record.errors.attribute_names, :display_position
  end

  test 'sort_for_display orders by group, then position, then label' do
    physical = CustomAttribute.new(label: 'weight', display_group: 'physical', display_position: 10)
    design_late = CustomAttribute.new(label: 'assembly', display_group: 'design', display_position: 20)
    design_early = CustomAttribute.new(label: 'cartridge_type', display_group: 'design', display_position: 10)
    tie = CustomAttribute.new(label: 'amplifier_type', display_group: 'design', display_position: 20)
    performance = CustomAttribute.new(label: 'nominal_impedance', display_group: 'performance', display_position: 5)

    sorted = CustomAttribute.sort_for_display([physical, design_late, performance, tie, design_early])

    assert_equal %w[cartridge_type amplifier_type assembly nominal_impedance weight], sorted.map(&:label)
  end

  test 'group_for_display returns only groups that have definitions, in group order' do
    weight = CustomAttribute.new(label: 'weight', display_group: 'physical', display_position: 20)
    dimensions = CustomAttribute.new(label: 'dimensions', display_group: 'physical', display_position: 10)
    assembly = CustomAttribute.new(label: 'assembly', display_group: 'design', display_position: 10)

    grouped = CustomAttribute.group_for_display([weight, assembly, dimensions])

    assert_equal %w[design physical], grouped.map(&:first)
    assert_equal %w[dimensions weight], grouped.last.last.map(&:label)
  end

  test 'every valid qualifier has a custom_attribute_qualifiers translation' do
    untranslated = CustomAttribute::VALID_QUALIFIERS.reject do |qualifier|
      I18n.exists?("custom_attribute_qualifiers.#{qualifier}")
    end

    assert_empty untranslated
  end

  # These three units are not offered by any definition any more: dB@1W/1m and dB@2.83V/1m became
  # qualifiers of `loudspeaker_sensitivity`, and dB/mW will go the same way. They must stay in the
  # locale file regardless. `_changelog.html.erb` and `AdminVersionActivityPresenter` render the
  # unit of an older PaperTrail version, so a tidy-up that removes these keys prints "translation
  # missing" in the history of every product that carried one.
  test 'the units that became qualifiers keep their translations' do
    %w[db_1w_1m db_283v_1m db_mw].each do |unit|
      assert I18n.exists?("custom_attribute_units.#{unit}"), "custom_attribute_units.#{unit} is gone"
    end
  end

  # The rule the sensitivity migration restored: two readings of one figure that no factor relates
  # are not two units, they are one unit and two qualifiers. Only the definitions of this
  # environment are checked, so this guards the fixtures rather than production data -- but it is
  # the rule a new definition is most likely to break.
  test 'no definition offers two units that cannot convert into each other' do
    CustomAttribute.where(input_type: 'number').find_each do |definition|
      next unless definition.units.size == 2

      pair = CustomAttribute.equivalent_unit(definition.units.first)

      assert_equal definition.units.last, pair&.first,
                   "#{definition.label} offers #{definition.units.join(' and ')}, which do not " \
                   'convert. A second reading of one figure belongs in qualifiers.'
    end
  end

  # A convertible unit that is not offerable is a factor nothing can reach; a unit pair whose
  # canonical half is missing would let a definition offer two units that filtering then
  # normalises to a unit no product stores.
  test 'both halves of every unit conversion are offerable units' do
    CustomAttribute::UNIT_CONVERSIONS.each do |from, (to, _factor)|
      assert_includes CustomAttribute::VALID_UNITS, from
      assert_includes CustomAttribute::VALID_UNITS, to
    end
  end

  test 'partner_unit and imperial_unit? answer from both sides of a pair' do
    assert_equal 'lb', CustomAttribute.partner_unit('kg')
    assert_equal 'kg', CustomAttribute.partner_unit('lb')
    assert_nil CustomAttribute.partner_unit('ohm')

    assert CustomAttribute.imperial_unit?('lb')
    assert CustomAttribute.imperial_unit?('in')
    assert_not CustomAttribute.imperial_unit?('kg')
    assert_not CustomAttribute.imperial_unit?(nil)
  end

  test 'equivalent_unit answers from both sides of a pair and nil otherwise' do
    other_unit, factor = CustomAttribute.equivalent_unit('cm')
    assert_equal 'in', other_unit
    assert_in_delta 0.3937, factor, 0.0001

    other_unit, factor = CustomAttribute.equivalent_unit('in')
    assert_equal 'cm', other_unit
    assert_in_delta 2.54, factor

    # Two units on one definition are not always a convertible pair: loudspeaker_sensitivity
    # offers two different measurements, not two spellings of one.
    assert_nil CustomAttribute.equivalent_unit('db_1w_1m')
  end

  test 'unit_pair? is true only for the two units of one pair, and paired_units puts metric first' do
    definition = custom_attributes(:four)

    definition.units = %w[lb kg]
    assert definition.unit_pair?
    assert_equal %w[kg lb], definition.paired_units

    definition.units = %w[kg]
    assert_not definition.unit_pair?
    assert_empty definition.paired_units

    definition.units = %w[kg in]
    assert_not definition.unit_pair?
  end

  test 'stated_figures lists value first and ignores blank figures' do
    entry = { 'value' => 15, 'unit' => 'kg', 'second' => { 'value' => 33, 'unit' => 'lb' } }

    assert_equal({ 'kg' => 15, 'lb' => 33 }, CustomAttribute.stated_figures(entry))
    assert_equal({ 'kg' => 15 }, CustomAttribute.stated_figures(entry.merge('second' => { 'unit' => 'lb' })))
    assert_equal({}, CustomAttribute.stated_figures({ 'value' => 15 }))
    assert_equal({}, CustomAttribute.stated_figures(nil))
  end

  # ProductFilterService#converted_figure_sql counts the same way; see its test.
  test 'significant_figures counts the digits of the stored number, never fewer than two' do
    assert_equal 2, CustomAttribute.significant_figures(15.0)
    assert_equal 2, CustomAttribute.significant_figures(0.2)
    assert_equal 3, CustomAttribute.significant_figures(1.35)
    assert_equal 3, CustomAttribute.significant_figures(200)
    assert_equal 3, CustomAttribute.significant_figures(0.0119)
  end

  test 'converted_figure rounds to the significant figures of the stated figure' do
    assert_equal ['lb', 33.0], CustomAttribute.converted_figure(15.0, 'kg')
    assert_equal ['in', 5.9], CustomAttribute.converted_figure(15, 'cm')
    assert_equal ['lb', 0.44], CustomAttribute.converted_figure(0.2, 'kg')
    assert_equal ['lb', 2.98], CustomAttribute.converted_figure(1.35, 'kg')
    assert_equal ['kg', 15.0], CustomAttribute.converted_figure(33, 'lb')
    assert_equal ['lb', 0.0], CustomAttribute.converted_figure(0, 'kg')
    assert_nil CustomAttribute.converted_figure(8, 'ohm')
  end

  test 'figures_agree? compares the rounding ranges of the two figures' do
    assert CustomAttribute.figures_agree?(15, 'kg', 33, 'lb')
    # 0.7 lb is 0.65 to 0.75 lb, which reaches 0.3 kg although the two differ by 5.8 %.
    assert CustomAttribute.figures_agree?(0.3, 'kg', 0.7, 'lb')
    assert_not CustomAttribute.figures_agree?(15, 'kg', 22, 'lb')
    assert_not CustomAttribute.figures_agree?(70, 'kg', 165, 'lb')

    assert CustomAttribute.figures_agree?({ 'w' => 43, 'h' => 12 }, 'cm', { 'w' => 17, 'h' => 4.7 }, 'in')
    assert_not CustomAttribute.figures_agree?({ 'w' => 43, 'h' => 12 }, 'cm', { 'w' => 17, 'h' => 5.7 }, 'in')
  end

  test 'pruned_entry keeps a second figure in the counterpart unit of a pair' do
    definition = custom_attributes(:four)
    definition.units = %w[lb kg]
    entry = { 'value' => 15, 'unit' => 'kg', 'second' => { 'value' => 33, 'unit' => 'lb', 'extra' => 1 } }

    assert_equal({ 'value' => 33, 'unit' => 'lb' }, definition.pruned_entry(entry)['second'])
  end

  test 'pruned_entry drops a second figure the definition cannot place' do
    definition = custom_attributes(:four)
    definition.units = %w[lb kg]

    same_unit = { 'value' => 15, 'unit' => 'kg', 'second' => { 'value' => 15, 'unit' => 'kg' } }
    blank = { 'value' => 15, 'unit' => 'kg', 'second' => { 'value' => '', 'unit' => 'lb' } }
    assert_not definition.pruned_entry(same_unit).key?('second')
    assert_not definition.pruned_entry(blank).key?('second')

    definition.units = %w[kg]
    assert_not definition.pruned_entry(blank.merge('second' => { 'value' => 33, 'unit' => 'lb' })).key?('second')
  end

  # Metric in `value`, imperial in `second`, so the same two figures always have the same shape
  # and the changelog shows no change when only their order changed.
  test 'order_figures puts the metric figure into value' do
    ordered = CustomAttribute.order_figures(
      'weight' => { 'value' => 33, 'unit' => 'lb', 'second' => { 'value' => 15, 'unit' => 'kg' }, 'qualifier' => 'x' }
    )

    assert_equal(
      { 'value' => 15, 'unit' => 'kg', 'second' => { 'value' => 33, 'unit' => 'lb' }, 'qualifier' => 'x' },
      ordered['weight']
    )
    assert_equal ordered, CustomAttribute.order_figures(ordered)
  end

  test 'order_figures moves a lone second figure into value' do
    ordered = CustomAttribute.order_figures(
      'weight' => { 'unit' => 'kg', 'second' => { 'value' => 33, 'unit' => 'lb' } }
    )

    assert_equal({ 'value' => 33, 'unit' => 'lb' }, ordered['weight'])
  end

  test 'order_figures never converts a figure' do
    values = {
      'weight' => { 'value' => 2, 'unit' => 'lb' },
      'dimensions' => { 'value' => { 'w' => 2, 'h' => 4 }, 'unit' => 'in' },
      'loudspeaker_bi_wiring' => true,
      'no_such_attribute' => { 'value' => 2, 'unit' => 'lb' }
    }

    assert_equal values, CustomAttribute.order_figures(values)
  end

  # Left over when prune_unsupported_keys removes a `second` that was the only figure.
  test 'order_figures removes a number entry that holds no figure' do
    ordered = CustomAttribute.order_figures(
      'weight' => { 'unit' => 'kg' },
      'dimensions' => { 'value' => {}, 'unit' => 'cm' },
      'loudspeaker_bi_wiring' => false
    )

    assert_equal({ 'loudspeaker_bi_wiring' => false }, ordered)
  end

  test 'order_figures tolerates a blank attribute hash' do
    assert_nil CustomAttribute.order_figures(nil)
    assert_empty CustomAttribute.order_figures({})
  end

  # An attribute asks one question everywhere it applies, but not every answer applies
  # everywhere: `input_connectors` is one question, and a phono stage answers it with RCA and
  # XLR where a DAC answers it with USB and TOSLINK. The subset lives on the join row.
  def link_between(attribute, sub_category)
    CustomAttributeSubCategory.find_by!(custom_attribute: attribute, sub_category: sub_category)
  end

  test 'options_for returns everything while no sub category narrows the list' do
    attribute = custom_attributes(:three)

    assert_equal attribute.options, attribute.options_for([@sub_category.id])
    assert_not_predicate attribute, :option_scoped?
  end

  test 'options_for narrows to a sub category subset' do
    attribute = custom_attributes(:three)
    link_between(attribute, @sub_category).update!(option_ids: %w[1])

    assert_equal({ '1' => 'coaxial' }, attribute.options_for([@sub_category.id]))
    assert_predicate attribute, :option_scoped?
  end

  # A union, not an intersection: a product in two sub categories genuinely is both, so an
  # option either one offers is a legitimate answer.
  test 'options_for unions the subsets of several sub categories' do
    attribute = custom_attributes(:three)
    link_between(attribute, sub_categories(:one)).update!(option_ids: %w[1])
    link_between(attribute, sub_categories(:two)).update!(option_ids: %w[2])

    scoped = attribute.options_for([sub_categories(:one).id, sub_categories(:two).id])

    assert_equal %w[1 2], scoped.keys.sort
  end

  # Which is why leaving the subset unset is always safe: it means "everything applies here".
  test 'an unscoped sub category widens the union back to every option' do
    attribute = custom_attributes(:three)
    link_between(attribute, sub_categories(:one)).update!(option_ids: %w[1])

    scoped = attribute.options_for([sub_categories(:one).id, sub_categories(:two).id])

    assert_equal attribute.options, scoped
  end

  test 'options_for ignores sub categories the attribute does not apply to' do
    attribute = custom_attributes(:three)
    link_between(attribute, @sub_category).update!(option_ids: %w[1])

    assert_equal attribute.options, attribute.options_for([-1])
  end

  test 'options_for preserves the definition ordering' do
    attribute = custom_attributes(:three)
    link_between(attribute, @sub_category).update!(option_ids: %w[2 1])

    assert_equal attribute.options.keys, attribute.options_for([@sub_category.id]).keys
  end

  test 'sub_category_ids_for_option counts unscoped sub categories as offering everything' do
    attribute = custom_attributes(:three)
    link_between(attribute, sub_categories(:one)).update!(option_ids: %w[1])

    assert_equal [sub_categories(:one).id, sub_categories(:two).id].sort,
                 attribute.sub_category_ids_for_option('1').sort
    assert_equal [sub_categories(:two).id], attribute.sub_category_ids_for_option('2')
  end

  test 'option_scopes= narrows a sub category from the admin form' do
    attribute = custom_attributes(:three)
    attribute.option_scopes = { @sub_category.id.to_s => ['', '1'] }
    attribute.save!

    assert_equal %w[1], link_between(attribute, @sub_category).option_ids
  end

  # Storing the full list instead would freeze that sub category at today's options: the whole
  # feature rests on an empty subset meaning "all of them", including ones added later.
  test 'option_scopes= stores every option ticked as unset rather than as the full list' do
    attribute = custom_attributes(:three)
    link_between(attribute, @sub_category).update!(option_ids: %w[1])

    attribute.option_scopes = { @sub_category.id.to_s => ['', '1', '2'] }
    attribute.save!

    assert_empty link_between(attribute, @sub_category).option_ids
  end

  test 'option_scopes= leaves a sub category the form did not submit alone' do
    attribute = custom_attributes(:three)
    link_between(attribute, sub_categories(:two)).update!(option_ids: %w[2])

    attribute.option_scopes = { sub_categories(:one).id.to_s => ['', '1'] }
    attribute.save!

    assert_equal %w[2], link_between(attribute, sub_categories(:two)).option_ids
  end

  test 'option_scopes= ignores ids the attribute does not define' do
    attribute = custom_attributes(:three)
    attribute.option_scopes = { @sub_category.id.to_s => ['', '1', '99'] }
    attribute.save!

    assert_equal %w[1], link_between(attribute, @sub_category).option_ids
  end

  test 'an option id the attribute does not define is rejected on the join row' do
    link = link_between(custom_attributes(:three), @sub_category)
    link.option_ids = %w[99]

    assert_not link.valid?
    assert_match(/are not options of/, link.errors[:option_ids].join(' '))
  end

  # The join rows are written by HABTM -- `attribute.sub_categories = [...]` -- which never
  # loads CustomAttributeSubCategory, so its own callback cannot be what keeps this fresh.
  test 'saving an attribute invalidates the sub category scope map' do
    with_memory_cache do
      CustomAttribute.sub_category_scopes_cached

      assert Rails.cache.exist?('custom_attribute_sub_category_scopes')

      custom_attributes(:three).update!(highlighted: true)

      assert_not Rails.cache.exist?('custom_attribute_sub_category_scopes')
    end
  end

  # A change of `highlighted` can change the completeness of all products in the attribute's sub
  # categories. The attribute enqueues that work; it does not do it in the request.
  test 'a change of highlighted enqueues one completeness job per sub category' do
    attribute = custom_attributes(:three)

    assert_enqueued_jobs attribute.sub_category_ids.size, only: SubCategoryCompletenessJob do
      attribute.update!(highlighted: true)
    end
  end

  test 'a save without a change of highlighted enqueues no completeness job' do
    attribute = custom_attributes(:three)

    assert_no_enqueued_jobs only: SubCategoryCompletenessJob do
      attribute.update!(label: attribute.label)
    end
  end

  def with_memory_cache
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = previous
  end

  test 'units_must_be_valid rejects unknown units' do
    record = CustomAttribute.new(
      label: 'headphone_sensitivity',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'number',
      units: %w[km]
    )

    record.sub_categories << @sub_category
    assert_not record.valid?
    assert_match(/contain invalid values/, record.errors[:units].join(' '))
  end

  test 'inputs_must_be_valid rejects unknown inputs' do
    record = CustomAttribute.new(
      label: 'loudspeaker_recommended_amplifier_power',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'number',
      inputs: %w[width]
    )

    record.sub_categories << @sub_category
    assert_not record.valid?
    assert_match(/contain invalid values/, record.errors[:inputs].join(' '))
    assert_empty record.errors[:units]
  end

  # Amplifier power is quoted per load impedance, which is what these exist for. Kept as two
  # sets rather than one of six: `inputs` is what the product form renders as fields, and a
  # power amplifier should not be asked for its output into 300 ohms.
  test 'impedance inputs are offerable and translated' do
    %w[ohm_2 ohm_4 ohm_8 ohm_32 ohm_300 ohm_600].each do |input|
      assert_includes CustomAttribute::VALID_INPUTS, input
    end

    record = CustomAttribute.new(
      label: 'loudspeaker_recommended_amplifier_power',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'number',
      inputs: %w[ohm_8 ohm_4],
      units: %w[w]
    )

    record.sub_categories << @sub_category

    assert record.valid?, record.errors.full_messages.to_sentence
  end

  test 'before_validation compacts blanks on units and inputs arrays' do
    record = CustomAttribute.new(
      label: 'frequency_response_range',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'number',
      units: ['cm', nil, '', 'in'],
      inputs: ['w', '', nil],
      qualifiers: ['plus_minus_3_db', '', nil]
    )

    record.sub_categories << @sub_category
    assert record.valid?, record.errors.full_messages.to_sentence
    assert_equal %w[cm in], record.units.sort
    assert_equal ['w'], record.inputs
    assert_equal ['plus_minus_3_db'], record.qualifiers
  end

  test 'qualifiers_must_be_valid rejects unknown qualifiers' do
    record = CustomAttribute.new(
      label: 'frequency_response_range',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'number',
      qualifiers: %w[at_midnight]
    )

    record.sub_categories << @sub_category
    assert_not record.valid?
    assert_match(/contain invalid values/, record.errors[:qualifiers].join(' '))
    assert_empty record.errors[:units]
    assert_empty record.errors[:inputs]
  end

  # Same rule as units and inputs: the product form branches on the configuration rather than on
  # the input type, so a condition left behind by a type change would be offered for a value that
  # is no longer a measurement.
  test 'switching away from number clears qualifiers' do
    record = CustomAttribute.new(
      label: 'frequency_response_range',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'number',
      units: %w[hz],
      qualifiers: %w[plus_minus_3_db]
    )
    record.sub_categories << @sub_category
    record.save!

    record.input_type = 'boolean'

    assert record.valid?, record.errors.full_messages.to_sentence
    assert_empty record.qualifiers
  end

  test 'qualified? is true only for a number attribute that offers conditions' do
    record = CustomAttribute.new(label: 'frequency_response_range', highlighted: true, input_type: 'number')

    assert_not record.qualified?

    record.qualifiers = %w[plus_minus_3_db]

    assert record.qualified?
    assert record.qualifier?('plus_minus_3_db')
    assert_not record.qualifier?('plus_minus_6_db')
    assert_not record.qualifier?('')
    assert_not record.qualifier?(nil)
  end

  test 'qualifier_label translates a stored entry and answers nil without one' do
    entry = { 'value' => 20, 'unit' => 'hz', 'qualifier' => 'plus_minus_3_db' }

    assert_equal I18n.t('custom_attribute_qualifiers.plus_minus_3_db'), CustomAttribute.qualifier_label(entry)
    assert_nil CustomAttribute.qualifier_label({ 'value' => 20, 'unit' => 'hz' })
    assert_nil CustomAttribute.qualifier_label({ 'value' => 20, 'qualifier' => '' })
    assert_nil CustomAttribute.qualifier_label(nil)
    assert_nil CustomAttribute.qualifier_label('20')
  end

  test 'prune_unsupported_keys drops a unit and a condition the definition does not offer' do
    custom_attributes(:four).update!(units: %w[kg lb], qualifiers: %w[plus_minus_3_db])

    with_memory_cache do
      pruned = CustomAttribute.prune_unsupported_keys(
        'weight' => { 'value' => 2, 'unit' => 'furlong', 'qualifier' => 'thd_1_percent' }
      )

      assert_equal 2, pruned['weight']['value']
      assert_not pruned['weight'].key?('unit')
      assert_not pruned['weight'].key?('qualifier')
    end
  end

  # A definition that declares no units says nothing about them, and neither does the filter, which
  # applies a unit predicate only when the definition has some. Removing the unit here would
  # accomplish nothing.
  test 'prune_unsupported_keys keeps a unit when the definition declares none' do
    custom_attributes(:four).update!(units: [], qualifiers: %w[plus_minus_3_db])

    with_memory_cache do
      pruned = CustomAttribute.prune_unsupported_keys(
        'weight' => { 'value' => 2, 'unit' => 'lb', 'qualifier' => 'thd_1_percent' }
      )

      assert_equal 'lb', pruned['weight']['unit']
      assert_not pruned['weight'].key?('qualifier')
    end
  end

  # The opposite for a condition: no declared qualifiers means the definition asks no question, so
  # a stored answer is not one. It would still render, because qualifier_label reads the entry.
  test 'prune_unsupported_keys drops a condition when the definition declares none' do
    custom_attributes(:four).update!(units: %w[kg lb], qualifiers: [])

    with_memory_cache do
      pruned = CustomAttribute.prune_unsupported_keys(
        'weight' => { 'value' => 2, 'unit' => 'kg', 'qualifier' => 'plus_minus_3_db' }
      )

      assert_equal 'kg', pruned['weight']['unit']
      assert_not pruned['weight'].key?('qualifier')
    end
  end

  test 'prune_unsupported_keys keeps what the definition offers and drops blanks' do
    custom_attributes(:four).update!(units: %w[kg lb], qualifiers: %w[plus_minus_3_db])

    with_memory_cache do
      pruned = CustomAttribute.prune_unsupported_keys(
        'weight' => { 'value' => 2, 'unit' => 'kg', 'qualifier' => '' }
      )

      assert_equal 'kg', pruned['weight']['unit']
      assert_not pruned['weight'].key?('qualifier')
    end
  end

  test 'before_save parses options when options is JSON string' do
    parsed = { '1' => 'optical' }

    record = CustomAttribute.new(
      label: 'cartridge_type',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'option',
      options: parsed.to_json
    )

    record.sub_categories << @sub_category
    record.save!

    assert_equal parsed, CustomAttribute.find_by(label: 'cartridge_type').options
  end

  test 'before_save sets options to nil when options blank after cast' do
    record = CustomAttribute.new(
      label: 'loudspeaker_bi_amping',
      highlighted: true,
      display_group: 'design',
      display_position: 10,
      input_type: 'boolean',
      options: nil
    )

    record.sub_categories << @sub_category
    record.save!

    assert_nil CustomAttribute.find_by(label: 'loudspeaker_bi_amping').options
  end

  test 'switching away from an option input type clears the options' do
    record = custom_attributes(:one)
    record.update!(input_type: 'boolean')

    assert_nil record.reload.options
  end

  test 'switching between the two option input types keeps the options' do
    record = custom_attributes(:one)
    record.update!(input_type: 'options')

    assert_equal({ '1' => 'stereo', '2' => 'dual-mono' }, record.reload.options)
  end

  test 'switching away from the number input type clears units and inputs' do
    record = custom_attributes(:six)
    record.update!(input_type: 'boolean', highlighted: true)
    record.reload

    assert_empty record.units
    assert_empty record.inputs
  end

  test 'a blank input type leaves the existing configuration alone' do
    record = custom_attributes(:one)
    record.input_type = nil

    assert record.valid?
    assert_equal({ '1' => 'stereo', '2' => 'dual-mono' }, record.options)
  end

  test 'options_attributes= keeps existing ids and assigns new ones above the highest seen' do
    record = custom_attributes(:one)

    record.options_attributes = [
      { 'key' => '1', 'value' => 'stereo' },
      { 'key' => '', 'value' => 'mono' }
    ]

    assert_equal({ '1' => 'stereo', '3' => 'mono' }, record.options)
  end

  test 'options_attributes= never reuses an id freed in the same submit' do
    record = custom_attributes(:one)

    record.options_attributes = [{ 'key' => '', 'value' => 'mono' }]

    assert_equal({ '3' => 'mono' }, record.options)
  end

  test 'options_attributes= relabels an option without renumbering it' do
    record = custom_attributes(:two)

    record.options_attributes = [
      { 'key' => '1', 'value' => 'direct-drive' },
      { 'key' => '2', 'value' => 'belt-drive' }
    ]

    assert_equal({ '1' => 'direct-drive', '2' => 'belt-drive' }, record.options)
  end

  test 'options_attributes= drops blank rows and strips values' do
    record = custom_attributes(:one)

    record.options_attributes = [
      { 'key' => '1', 'value' => '  stereo  ' },
      { 'key' => '2', 'value' => '' },
      { 'key' => '', 'value' => nil }
    ]

    assert_equal({ '1' => 'stereo' }, record.options)
  end

  test 'options_attributes= sets options to nil when every row is empty' do
    record = custom_attributes(:one)

    record.options_attributes = []

    assert_nil record.options
  end

  test 'options_attributes= accepts the hash form rack may produce' do
    record = custom_attributes(:one)

    record.options_attributes = { '0' => { 'key' => '2', 'value' => 'mono' } }

    assert_equal({ '2' => 'mono' }, record.options)
  end

  test 'option_usage_counts counts products per option for a single-option attribute' do
    counts = custom_attributes(:one).option_usage_counts

    assert_equal 1, counts['1']
    assert_nil counts['2']
  end

  test 'option_usage_counts counts products per option for a multi-option attribute' do
    counts = custom_attributes(:three).option_usage_counts

    assert_equal 1, counts['1']
    assert_equal 1, counts['2']
  end

  test 'option_usage_counts is empty for attributes without options' do
    assert_empty custom_attributes(:four).option_usage_counts
    assert_empty custom_attributes(:five).option_usage_counts
  end

  test 'available_option_keys pairs every locale key with its translation' do
    keys = CustomAttribute.available_option_keys

    assert_includes keys, ['stereo', I18n.t('custom_attributes.stereo')]
    assert_equal keys.map(&:last).sort, keys.map(&:last)
  end

  test 'all_cached returns an array of attributes' do
    list = CustomAttribute.all_cached

    assert_kind_of Array, list
    assert_equal CustomAttribute.count, list.size
  end

  # Records cached before a migration do not have the new columns. See CustomAttribute.all_cached_key.
  test 'the all_cached key changes when the columns change' do
    fewer_columns = Class.new(CustomAttribute) do
      def self.column_names = super - ['display_group']
    end

    assert_not_equal CustomAttribute.all_cached_key, fewer_columns.all_cached_key
  end
  # RelatedProducts::Graph names attributes and option keys as Ruby constants, so nothing in the
  # database can enforce the reference. These guards refuse the edits that would break it.
  test 'a label the graph gates on cannot be renamed' do
    attribute = custom_attributes(:seven)

    assert_includes RelatedProducts::Graph.gate_attributes, 'amplifier_type'

    attribute.label = 'turntable_drive_type'

    assert_not attribute.valid?
    assert_includes attribute.errors[:label].join, 'RelatedProducts::Graph'
  end

  test 'a label the graph does not gate on can be renamed' do
    attribute = custom_attributes(:one)

    assert_not_includes RelatedProducts::Graph.gate_attributes, attribute.label
  end

  test 'a label the graph gates on cannot be destroyed' do
    attribute = custom_attributes(:seven)

    assert_no_difference -> { CustomAttribute.count } do
      assert_not attribute.destroy
    end
    assert_includes attribute.errors[:base].join, 'cannot be deleted'
  end

  test 'an option key the graph references cannot be removed' do
    attribute = custom_attributes(:seven)

    assert_includes RelatedProducts::Graph.referenced_option_keys['amplifier_type'], 'tube'

    attribute.options = attribute.options.reject { |_id, key| key == 'tube' }

    assert_not attribute.valid?
    assert_includes attribute.errors[:options].join, 'tube'
  end

  test 'an option key the graph does not reference can be removed' do
    attribute = custom_attributes(:seven)

    assert_not_includes RelatedProducts::Graph.referenced_option_keys['amplifier_type'],
                        'solid_state'

    attribute.options = attribute.options.reject { |_id, key| key == 'solid_state' }

    assert_predicate attribute, :valid?
  end

  # Units per sub category. See docs/custom-attributes.md, "Units per sub category".

  test 'conversion_factor relates units through the scale and the pair tables' do
    assert_in_delta 0.001, CustomAttribute.conversion_factor('g', 'kg')
    assert_in_delta 1000.0, CustomAttribute.conversion_factor('kg', 'g')
    assert_in_delta 0.001 / 0.45359237, CustomAttribute.conversion_factor('g', 'lb')
    assert_in_delta 1.0, CustomAttribute.conversion_factor('kg', 'kg')
    assert_nil CustomAttribute.conversion_factor('g', 'cm')
  end

  test 'figure_in rounds to the significant figures of the stated figure' do
    assert_in_delta 6.5, CustomAttribute.figure_in(0.0065, 'kg', 'g')
    assert_in_delta 0.0065, CustomAttribute.figure_in(6.5, 'g', 'kg')
    assert_nil CustomAttribute.figure_in(6.5, 'g', 'cm')
  end

  test 'a sub category offers its own units, and the filter of a page offers the units of all' do
    weight, cartridges = weight_with_gram_sub_category

    assert_equal %w[g], weight.units_in(cartridges.id)
    assert_equal %w[lb kg], weight.units_in(sub_categories(:one).id)
    assert_equal %w[lb kg g], weight.filter_units_for([sub_categories(:one).id, cartridges.id])
    assert_equal %w[g], weight.filter_units_for([cartridges.id])
    assert_equal [%w[lb kg], %w[g]], weight.unit_variants.map(&:first)
  end

  test 'units_for uses the units of the first sub category in menu order' do
    weight, cartridges = weight_with_gram_sub_category
    ranks = { cartridges.id => 0, sub_categories(:one).id => 1 }

    assert_equal %w[g], weight.units_for([sub_categories(:one).id, cartridges.id], ranks:)
    assert_equal %w[lb kg], weight.units_for([sub_categories(:one).id], ranks:)
    assert_equal %w[lb kg g], weight.units_for([sub_categories(:three).id], ranks:)
  end

  # A link written by another path than the admin form, for example the Sub Category admin.
  test 'a sub category without units falls back to all units of the definition' do
    weight, cartridges = weight_with_gram_sub_category
    CustomAttributeSubCategory.find_by!(custom_attribute: weight, sub_category: cartridges).update!(units: [])

    assert_equal %w[lb kg g], weight.units_in(cartridges.id)
  end

  test 'with_units returns a read-only copy that keeps the units of the definition' do
    weight, = weight_with_gram_sub_category
    copy = weight.with_units(%w[g])

    assert_equal weight.id, copy.id
    assert_equal %w[g], copy.units
    assert_equal %w[lb kg g], copy.base_units
    assert_predicate copy, :readonly?
    assert_same weight, weight.with_units(%w[lb kg g])
  end

  test 'converted_filter? is true for units that convert and for other units than the definition' do
    weight, = weight_with_gram_sub_category

    assert_predicate weight, :converted_filter?
    assert_predicate weight.with_units(%w[g]), :converted_filter?
    assert_not custom_attributes(:four).tap { |definition| definition.units = %w[kg] }.converted_filter?
  end

  test 'offers_pair? and partner_offered? read the units of the definition' do
    weight, = weight_with_gram_sub_category

    assert_predicate weight, :offers_pair?
    assert weight.partner_offered?('kg')
    assert_not weight.partner_offered?('g')
    assert_not weight.with_units(%w[g]).offers_pair?
  end

  test 'entry_in_own_units converts a figure into the units of the sub category' do
    weight, = weight_with_gram_sub_category
    grams = weight.with_units(%w[g])

    assert_equal({ 'value' => 6.5, 'unit' => 'g' }, grams.entry_in_own_units({ 'value' => 0.0065, 'unit' => 'kg' }))
    assert_equal({ 'value' => 6.5, 'unit' => 'g' }, grams.entry_in_own_units({ 'value' => 6.5, 'unit' => 'g' }))
    # Without a unit, the entry reads in the first unit of the definition.
    assert_equal({ 'value' => 15, 'unit' => 'lb' }, weight.entry_in_own_units({ 'value' => 15 }))
  end

  test 'prune_unsupported_keys keeps a unit of the definition that only a sub category offers' do
    weight_with_gram_sub_category

    pruned = CustomAttribute.prune_unsupported_keys('weight' => { 'value' => 6.5, 'unit' => 'g' })

    assert_equal 'g', pruned.dig('weight', 'unit')
  end

  test 'the units of a sub category are units of the definition' do
    weight, cartridges = weight_with_gram_sub_category
    link = CustomAttributeSubCategory.find_by!(custom_attribute: weight, sub_category: cartridges)

    link.units = %w[cm]
    assert_not link.valid?
    assert_match(/are not units of the attribute: cm/, link.errors[:units].join)

    link.units = %w[nope]
    assert_not link.valid?
    assert_match(/invalid values: nope/, link.errors[:units].join)
  end

  test 'the admin form stores the ticked units of each sub category' do
    weight, cartridges = weight_with_gram_sub_category

    weight.update!(unit_scopes: {
                     cartridges.id.to_s => ['', 'g', 'kg'],
                     sub_categories(:one).id.to_s => ['', 'kg', 'lb'],
                     sub_categories(:two).id.to_s => ['', 'kg']
                   })

    # In the order of the definition.
    assert_equal %w[kg g], weight.units_in(cartridges.id)
    assert_equal %w[lb kg], weight.units_in(sub_categories(:one).id)
    assert_equal %w[kg], weight.units_in(sub_categories(:two).id)
  end

  test 'the admin form requires a unit for each sub category' do
    weight, cartridges = weight_with_gram_sub_category

    weight.unit_scopes = { cartridges.id.to_s => [''] }

    assert_not weight.valid?
    assert_match(/need at least one unit ticked for each category: Cartridges/, weight.errors[:units].join)
  end

  test 'a unit removed from the definition leaves the sub categories' do
    weight, cartridges = weight_with_gram_sub_category

    weight.update!(units: %w[lb kg])

    assert_equal %w[lb kg], weight.units_in(sub_categories(:one).id)
    assert_empty CustomAttributeSubCategory.find_by!(custom_attribute: weight, sub_category: cartridges).units
  end

  test 'the admin form refuses to remove the only unit of a sub category' do
    weight, cartridges = weight_with_gram_sub_category

    weight.assign_attributes(units: %w[lb kg], unit_scopes: { cartridges.id.to_s => ['', 'g'] })

    assert_not weight.valid?
    assert_match(/Cartridges/, weight.errors[:units].join)
  end

  test 'the units of a definition convert to each other' do
    definition = custom_attributes(:four)

    definition.units = %w[lb kg g]
    assert_predicate definition, :valid?

    definition.units = %w[kg cm]
    assert_not definition.valid?
    assert_match(/do not convert to kg: cm/, definition.errors[:units].join)
  end

  # The bulk definition task switches the units, for example from mm to cm.
  test 'tick_all_units_where_missing ticks all units for a sub category that keeps none of its units' do
    weight, cartridges = weight_with_gram_sub_category

    weight.units = %w[lb kg]
    weight.tick_all_units_where_missing
    weight.save!

    assert_equal %w[lb kg], weight.units_in(cartridges.id)
    assert_equal %w[lb kg], weight.units_in(sub_categories(:one).id)
  end

  test 'tick_all_units_where_missing ticks all units for the sub categories without units' do
    weight, cartridges = weight_with_gram_sub_category
    CustomAttributeSubCategory.find_by!(custom_attribute: weight, sub_category: sub_categories(:one)).update!(units: [])

    weight.tick_all_units_where_missing
    weight.save!

    assert_equal %w[lb kg g], weight.units_in(sub_categories(:one).id)
    assert_equal %w[g], weight.units_in(cartridges.id)
  end

  private

  def weight_with_gram_sub_category
    weight = custom_attributes(:four)
    weight.update!(units: %w[lb kg g])
    cartridges = SubCategory.create!(name: 'Cartridges', category: categories(:one))
    weight.sub_categories << cartridges
    links = CustomAttributeSubCategory.where(custom_attribute: weight)
    links.where.not(sub_category: cartridges).find_each { |link| link.update!(units: %w[lb kg]) }
    links.find_by!(sub_category: cartridges).update!(units: %w[g])

    [weight, cartridges]
  end
end
