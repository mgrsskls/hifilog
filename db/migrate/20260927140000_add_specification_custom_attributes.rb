# frozen_string_literal: true

# Adds the specifications that most sources state and that users compare or match gear by, and
# brings three existing definitions in line with how sources state them. The selection and the
# reasons for what was left out are in docs/custom-attributes.md, §9.
#
# Definitions are data rows, and this migration writes them with raw SQL, in the same way as
# MoveLoudspeakerSensitivityToQualifiers: the model validates its labels against the locale file
# and guards the related products graph, and neither has anything to say here. The translations
# ship in the same commit, so every label, option key and qualifier this writes has one.
#
# No new definition is highlighted. `highlighted` is what the completeness score counts, so a
# highlighted definition would lower the score of every product in its sub categories at once.
# Set it later, as a separate change.
#
# Sub categories are found by their `identifier`, which never changes (see SubCategory). An
# environment without one of them, for example a development database from the seeds, gets the
# definition without that link instead of an error.
class AddSpecificationCustomAttributes < ActiveRecord::Migration[8.1]
  DEFINITIONS = [
    {
      label: 'amplifier_class',
      input_type: 'option',
      display_group: 'design',
      display_position: 15,
      options: %w[class_a class_ab class_d other],
      sub_categories: %w[integrated-amplifiers power-amplifiers receivers headphone-amplifiers]
    },
    {
      label: 'stylus_shape',
      input_type: 'option',
      display_group: 'design',
      display_position: 25,
      options: %w[conical elliptical shibata line_contact other],
      sub_categories: %w[cartridges]
    },
    {
      label: 'woofer_size',
      input_type: 'number',
      display_group: 'design',
      display_position: 85,
      # A pair, so a source that states "6.5″ (16.5 cm)" keeps both figures.
      units: %w[cm in],
      sub_categories: %w[
        bookshelf-standmount-loudspeakers floorstanding-loudspeakers subwoofers center-channel-speakers
      ]
    },
    {
      label: 'turntable_speeds',
      input_type: 'options',
      display_group: 'design',
      display_position: 115,
      options: %w[rpm_33 rpm_45 rpm_78],
      sub_categories: %w[turntables]
    },
    {
      label: 'tape_head_configuration',
      input_type: 'option',
      display_group: 'design',
      display_position: 135,
      options: %w[heads_2 heads_3],
      sub_categories: %w[tape-decks]
    },
    {
      label: 'cartridge_output_voltage',
      input_type: 'number',
      display_group: 'performance',
      display_position: 120,
      units: %w[mv],
      # The stylus velocity of the test. 5 cm/s gives a figure about 3 dB higher than 3.54 cm/s.
      qualifiers: %w[velocity_5_cms velocity_3_54_cms],
      sub_categories: %w[cartridges]
    },
    {
      label: 'cartridge_compliance',
      input_type: 'number',
      display_group: 'performance',
      display_position: 130,
      units: %w[um_mn],
      # The test frequency. One cartridge gives a much higher figure at 10 Hz than at 100 Hz, so
      # two figures without this condition cannot be compared.
      qualifiers: %w[frequency_10hz frequency_100hz],
      sub_categories: %w[cartridges]
    },
    {
      label: 'tracking_force',
      input_type: 'number',
      display_group: 'performance',
      display_position: 140,
      units: %w[g],
      inputs: %w[min max],
      sub_categories: %w[cartridges]
    },
    {
      label: 'effective_mass',
      input_type: 'number',
      display_group: 'performance',
      display_position: 150,
      units: %w[g],
      # Turntables too: most of them come with an arm, and the arm is what the figure describes.
      sub_categories: %w[tonearms turntables]
    },
    {
      label: 'dsd_support',
      input_type: 'boolean',
      display_group: 'performance',
      display_position: 160,
      sub_categories: %w[dacs streamers cd-sacd-players daps]
    },
    {
      label: 'streaming_protocols',
      input_type: 'options',
      display_group: 'connectivity',
      display_position: 70,
      options: %w[airplay chromecast roon_ready upnp_dlna spotify_connect tidal_connect],
      sub_categories: %w[streamers integrated-amplifiers receivers]
    }
  ].freeze

  TOLERANCE = { label: 'frequency_response_range', qualifier: 'plus_minus_4_db', after: 'plus_minus_3_db' }.freeze
  CARTRIDGE_SUPPORT = { label: 'supported_cartridge_types', option: 'mi' }.freeze

  SENSITIVITY = 'headphone_sensitivity'
  SENSITIVITY_QUALIFIERS = %w[drive_1mw drive_1v].freeze

  def up
    DEFINITIONS.each { |definition| create_definition(definition) }
    add_tolerance
    add_cartridge_support
    move_headphone_sensitivity_to_qualifiers

    clear_caches
  end

  def down
    DEFINITIONS.each { |definition| drop_definition(definition[:label]) }
    remove_tolerance
    restore_headphone_sensitivity_unit

    # `mi` stays in supported_cartridge_types: products can hold it after `up`, and an option id
    # that products hold must not go (see CustomAttribute#options_attributes=). Nothing breaks
    # when it stays.

    clear_caches
  end

  private

  # ------------------------------------------------------------------------------ new definitions

  # Skips a label that exists, so a definition created by hand before this migration keeps its
  # settings, and a second run changes nothing.
  def create_definition(definition)
    return say("#{definition[:label]} exists, skipped") if definition_id(definition[:label])

    units = definition[:units] || []
    options = definition[:options]&.each_with_index&.to_h { |key, index| [(index + 1).to_s, key] }

    execute(<<~SQL.squish)
      INSERT INTO custom_attributes
        (label, input_type, highlighted, display_group, display_position, options, units, inputs, qualifiers)
      VALUES (
        #{quote(definition[:label])}, #{quote(definition[:input_type])}, FALSE,
        #{quote(definition[:display_group])}, #{definition[:display_position].to_i},
        #{options ? "#{quote(options.to_json)}::jsonb" : 'NULL'},
        #{quote(pg_array(units))}, #{quote(pg_array(definition[:inputs] || []))},
        #{quote(pg_array(definition[:qualifiers] || []))}
      )
    SQL

    link_sub_categories(definition_id(definition[:label]), definition[:sub_categories], units)
  end

  # Each link needs its own units: the product form offers the units of the link, not of the
  # definition. See docs/custom-attributes.md, "Units per sub category".
  def link_sub_categories(attribute_id, identifiers, units)
    found = select_rows(<<~SQL.squish).to_h
      SELECT identifier, id FROM sub_categories WHERE identifier IN (#{quote_list(identifiers)})
    SQL

    (identifiers - found.keys).each { |identifier| say("no sub category #{identifier}, link skipped") }

    found.each_value do |sub_category_id|
      execute(<<~SQL.squish)
        INSERT INTO custom_attributes_sub_categories (custom_attribute_id, sub_category_id, option_ids, units)
        VALUES (#{attribute_id.to_i}, #{sub_category_id.to_i}, '{}', #{quote(pg_array(units))})
      SQL
    end
  end

  # Removes the values as well: a value whose definition is gone is shown by nothing and filtered
  # by nothing.
  def drop_definition(label)
    attribute_id = definition_id(label)
    return unless attribute_id

    %w[products import_candidates].each do |table|
      execute(<<~SQL.squish)
        UPDATE #{table} SET custom_attributes = custom_attributes - #{quote(label)}
        WHERE custom_attributes ? #{quote(label)}
      SQL
    end
    execute("DELETE FROM custom_attributes_sub_categories WHERE custom_attribute_id = #{attribute_id.to_i}")
    execute("DELETE FROM custom_attributes WHERE id = #{attribute_id.to_i}")
  end

  # ----------------------------------------------------------------------- existing definitions

  # ±4 dB is the tolerance of all Klipsch Heritage loudspeakers. It goes after ±3 dB, because the
  # order in a group is from the tightest claim to the loosest.
  def add_tolerance
    qualifiers = qualifiers_of(TOLERANCE[:label])
    return if qualifiers.nil? || qualifiers.include?(TOLERANCE[:qualifier])

    index = qualifiers.index(TOLERANCE[:after])
    index ? qualifiers.insert(index + 1, TOLERANCE[:qualifier]) : qualifiers.push(TOLERANCE[:qualifier])

    set_qualifiers(TOLERANCE[:label], qualifiers)
  end

  def remove_tolerance
    qualifiers = qualifiers_of(TOLERANCE[:label])
    return if qualifiers.nil?

    remove_qualifier_from_values(TOLERANCE[:label], TOLERANCE[:qualifier])
    set_qualifiers(TOLERANCE[:label], qualifiers - [TOLERANCE[:qualifier]])
  end

  # `cartridge_type` offers moving iron, so a phono stage must be able to say it accepts one. Without
  # it the cartridge -> phono stage match in RelatedProducts::Graph can never find a stage for an MI
  # cartridge.
  #
  # A new option gets the next id above the highest one, as CustomAttribute#options_attributes=
  # gives it. Ids are never reused, because products store the id.
  def add_cartridge_support
    raw = select_value("SELECT options FROM custom_attributes WHERE label = #{quote(CARTRIDGE_SUPPORT[:label])}")
    return if raw.nil?

    options = JSON.parse(raw)
    return if options.value?(CARTRIDGE_SUPPORT[:option])

    next_id = (options.keys.filter_map { |key| key[/\A\d+\z/]&.to_i }.max.to_i + 1).to_s
    options[next_id] = CARTRIDGE_SUPPORT[:option]

    execute(<<~SQL.squish)
      UPDATE custom_attributes SET options = #{quote(options.to_json)}::jsonb
      WHERE label = #{quote(CARTRIDGE_SUPPORT[:label])}
    SQL
  end

  # dB/mW was a unit until now. It is one unit, dB, specified at a drive reference of 1 mW, and the
  # other reference in use is 1 V. The two do not convert without the impedance of the product,
  # so they are two qualifiers, as for loudspeaker_sensitivity. See
  # docs/custom-attribute-qualifiers.md, §3.3.
  #
  # A stored `db_mw` is evidence of the 1 mW reference: the product form offered no other unit, and
  # the importer wrote `db_mw` only when the source line said mW. An entry with no unit states no
  # reference, so it keeps none.
  def move_headphone_sensitivity_to_qualifiers
    %w[products import_candidates].each do |table|
      execute(<<~SQL.squish)
        UPDATE #{table}
        SET custom_attributes = jsonb_set(
          jsonb_set(custom_attributes, ARRAY[#{quote(SENSITIVITY)}, 'unit'], to_jsonb('db'::text)),
          ARRAY[#{quote(SENSITIVITY)}, 'qualifier'], to_jsonb('drive_1mw'::text)
        )
        WHERE custom_attributes ? #{quote(SENSITIVITY)}
          AND custom_attributes -> #{quote(SENSITIVITY)} ->> 'unit' = 'db_mw'
      SQL
    end

    set_units(SENSITIVITY, %w[db])
    set_qualifiers(SENSITIVITY, SENSITIVITY_QUALIFIERS)
  end

  # A 1 V figure has no dB/mW value to go back to, so it loses its unit instead of getting a wrong
  # one. The figure stays.
  def restore_headphone_sensitivity_unit
    %w[products import_candidates].each do |table|
      execute(<<~SQL.squish)
        UPDATE #{table}
        SET custom_attributes =
          jsonb_set(custom_attributes, ARRAY[#{quote(SENSITIVITY)}, 'unit'], to_jsonb('db_mw'::text))
          #- ARRAY[#{quote(SENSITIVITY)}, 'qualifier']
        WHERE custom_attributes ? #{quote(SENSITIVITY)}
          AND custom_attributes -> #{quote(SENSITIVITY)} ->> 'qualifier' = 'drive_1mw'
      SQL
      execute(<<~SQL.squish)
        UPDATE #{table}
        SET custom_attributes = custom_attributes
          #- ARRAY[#{quote(SENSITIVITY)}, 'unit'] #- ARRAY[#{quote(SENSITIVITY)}, 'qualifier']
        WHERE custom_attributes ? #{quote(SENSITIVITY)}
          AND custom_attributes -> #{quote(SENSITIVITY)} ->> 'unit' = 'db'
      SQL
    end

    set_units(SENSITIVITY, %w[db_mw])
    set_qualifiers(SENSITIVITY, [])
  end

  # ------------------------------------------------------------------------------------ helpers

  def remove_qualifier_from_values(label, qualifier)
    %w[products import_candidates].each do |table|
      execute(<<~SQL.squish)
        UPDATE #{table} SET custom_attributes = custom_attributes #- ARRAY[#{quote(label)}, 'qualifier']
        WHERE custom_attributes ? #{quote(label)}
          AND custom_attributes -> #{quote(label)} ->> 'qualifier' = #{quote(qualifier)}
      SQL
    end
  end

  # nil when the definition does not exist in this environment.
  def qualifiers_of(label)
    return unless definition_id(label)

    select_values(<<~SQL.squish)
      SELECT q FROM custom_attributes, unnest(qualifiers) WITH ORDINALITY AS t(q, n)
      WHERE label = #{quote(label)} ORDER BY n
    SQL
  end

  def set_qualifiers(label, qualifiers)
    execute("UPDATE custom_attributes SET qualifiers = #{quote(pg_array(qualifiers))} WHERE label = #{quote(label)}")
  end

  # The links carry units of their own, and each must be a unit of the definition.
  def set_units(label, units)
    execute("UPDATE custom_attributes SET units = #{quote(pg_array(units))} WHERE label = #{quote(label)}")
    execute(<<~SQL.squish)
      UPDATE custom_attributes_sub_categories SET units = #{quote(pg_array(units))}
      WHERE custom_attribute_id = (SELECT id FROM custom_attributes WHERE label = #{quote(label)})
    SQL
  end

  def definition_id(label)
    select_value("SELECT id FROM custom_attributes WHERE label = #{quote(label)}")
  end

  # The definitions are cached, and a production cache survives a deploy. With a per-process store
  # (development with tmp/caching-dev.txt) a running server keeps its own copy: restart it.
  def clear_caches
    Rails.cache.delete(CustomAttribute.all_cached_key)
    CustomAttribute.clear_sub_category_scope_cache
  end

  def pg_array(values)
    "{#{values.join(',')}}"
  end

  def quote_list(values)
    values.map { |value| quote(value) }.join(', ')
  end

  # Every literal is quoted and spliced in; nothing goes through bind substitution. The jsonb
  # operators `?` and `#-` look like binds to Rails. See MoveLoudspeakerSensitivityToQualifiers.
  def quote(value)
    connection.quote(value)
  end
end
