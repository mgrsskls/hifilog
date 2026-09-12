# frozen_string_literal: true

require 'test_helper'

class CustomAttributeTest < ActiveSupport::TestCase
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

  # A convertible unit that is not offerable is a factor nothing can reach; a unit pair whose
  # canonical half is missing would let a definition offer two units that filtering then
  # normalises to a unit no product stores.
  test 'both halves of every unit conversion are offerable units' do
    CustomAttribute::UNIT_CONVERSIONS.each do |from, (to, _factor)|
      assert_includes CustomAttribute::VALID_UNITS, from
      assert_includes CustomAttribute::VALID_UNITS, to
    end
  end

  test 'canonical_unit maps a convertible unit to the one values are stored in' do
    assert_equal 'cm', CustomAttribute.canonical_unit('in')
    assert_equal 'kg', CustomAttribute.canonical_unit('lb')
    assert_equal 'm', CustomAttribute.canonical_unit('ft')
  end

  test 'canonical_unit leaves an unconvertible unit alone' do
    assert_equal 'ohm', CustomAttribute.canonical_unit('ohm')
    assert_equal 'mm', CustomAttribute.canonical_unit('mm')
  end

  test 'in_canonical_unit converts a value and passes nil through' do
    assert_in_delta 2.54, CustomAttribute.in_canonical_unit(1, 'in')
    assert_in_delta 5.0, CustomAttribute.in_canonical_unit(5, 'cm')
    assert_nil CustomAttribute.in_canonical_unit(nil, 'in')
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

  # Values are only findable under their canonical unit: filtering converts the submitted range
  # to the metric side of a pair and then matches the stored `unit` string, so anything stored
  # in pounds or inches is unreachable by any filter until it is rewritten.
  test 'normalize_units converts a scalar value into its canonical unit' do
    normalized = CustomAttribute.normalize_units('weight' => { 'value' => 2, 'unit' => 'lb' })

    assert_in_delta 0.90718474, normalized.dig('weight', 'value'), 0.000001
    assert_equal 'kg', normalized.dig('weight', 'unit')
  end

  test 'normalize_units converts every input of a multi input value' do
    normalized = CustomAttribute.normalize_units(
      'dimensions' => { 'value' => { 'w' => 2, 'h' => '4' }, 'unit' => 'in' }
    )

    assert_in_delta 5.08, normalized.dig('dimensions', 'value', 'w')
    assert_in_delta 10.16, normalized.dig('dimensions', 'value', 'h')
    assert_equal 'cm', normalized.dig('dimensions', 'unit')
  end

  test 'normalize_units is idempotent' do
    once = CustomAttribute.normalize_units('weight' => { 'value' => 2, 'unit' => 'lb' })
    twice = CustomAttribute.normalize_units(once)

    assert_equal once, twice
  end

  test 'normalize_units leaves canonical, unconvertible and unrecognised entries alone' do
    values = {
      'weight' => { 'value' => 3, 'unit' => 'kg' },
      'nominal_impedance' => { 'value' => 32, 'unit' => 'ohm' },
      'channel_configuration' => '1',
      'loudspeaker_bi_wiring' => true,
      'no_such_attribute' => { 'value' => 2, 'unit' => 'lb' }
    }

    assert_equal values, CustomAttribute.normalize_units(values)
  end

  test 'normalize_units passes through an entry with no usable number' do
    values = { 'weight' => { 'value' => '', 'unit' => 'lb' } }

    assert_equal values, CustomAttribute.normalize_units(values)
  end

  # All inputs of a multi input value share one `unit`, so a value where only some inputs are
  # numeric cannot be converted for those and left alone for the rest -- there is no unit left
  # to put on the unconverted ones. It must convert none of them, not silently drop the ones
  # it couldn't convert.
  test 'normalize_units leaves a multi input value alone when only some inputs are numeric' do
    values = { 'dimensions' => { 'value' => { 'w' => 2, 'h' => 'unknown' }, 'unit' => 'in' } }

    assert_equal values, CustomAttribute.normalize_units(values)
  end

  test 'normalize_units tolerates a blank attribute hash' do
    assert_nil CustomAttribute.normalize_units(nil)
    assert_empty CustomAttribute.normalize_units({})
  end

  # The three properties the product form's unit radios depend on. The conversion itself
  # happens in entity_form.js (setupUnitConversion) and cannot be exercised here -- there are
  # no system tests -- but the arithmetic it relies on lives in this model, so the invariants
  # are pinned where they are defined.
  #
  # Without them the radios are destructive: they declare the unit of the typed number, the
  # server normalises whatever arrives, and so toggling kg to lb on a value nobody retyped
  # rewrites it rather than restating it.
  test 'converting a value to its equivalent unit and back returns the original' do
    original = 0.90718474

    other_unit, factor = CustomAttribute.equivalent_unit('kg')
    displayed = (original * factor).round(6)

    back_unit, back_factor = CustomAttribute.equivalent_unit(other_unit)

    assert_equal 'kg', back_unit
    assert_in_delta original, (displayed * back_factor).round(6), 0.000001
  end

  # What the form posts when nothing but the unit radio was touched: the stored number, the
  # unit it is already in. Re-submitting a product unchanged must not move its values.
  test 'normalize_units is a no-op on values the form round-trips unchanged' do
    stored = {
      'weight' => { 'value' => 0.90718474, 'unit' => 'kg' },
      'dimensions' => { 'value' => { 'w' => 5.08, 'h' => 10.16 }, 'unit' => 'cm' }
    }

    assert_equal stored, CustomAttribute.normalize_units(stored)
  end

  # And what it posts once the JS has converted the number to go with the new radio: the
  # value comes back in canonical form, once, not twice.
  test 'normalize_units converts a form submission exactly once' do
    submitted = { 'weight' => { 'value' => '2', 'unit' => 'lb' } }

    once = CustomAttribute.normalize_units(submitted)

    assert_in_delta 0.90718474, once.dig('weight', 'value'), 0.000001
    assert_equal once, CustomAttribute.normalize_units(once)
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
      input_type: 'number',
      units: ['cm', nil, '', 'in'],
      inputs: ['w', '', nil]
    )

    record.sub_categories << @sub_category
    assert record.valid?, record.errors.full_messages.to_sentence
    assert_equal %w[cm in], record.units.sort
    assert_equal ['w'], record.inputs
  end

  test 'before_save parses options when options is JSON string' do
    parsed = { '1' => 'optical' }

    record = CustomAttribute.new(
      label: 'cartridge_type',
      highlighted: true,
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
end
