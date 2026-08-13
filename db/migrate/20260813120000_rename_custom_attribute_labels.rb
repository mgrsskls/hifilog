# frozen_string_literal: true

# Settles the custom attribute label convention before the label set roughly doubles.
#
# A label is a disambiguator, not a namespace. The subcategory join already scopes an
# attribute to where it applies, so a prefix that only restates the category buys nothing
# and costs something real: it forks one specification into two filter facets holding the
# same numbers in the same unit, which can then never be compared. A prefix earns its place
# only when two categories genuinely mean different things by the same word -- a different
# unit (`headphone_sensitivity` in dB/mW against `loudspeaker_sensitivity` in dB@1W/1m), a
# different option set, or a different question (what a thing *is* against what it
# *supports*).
#
# Three renames and three merges follow from that. The merges are the reason this cannot be
# a pure `rename_column`-style change: two definitions collapse into one, so the loser's
# subcategories move onto the winner and its rows are deleted.
#
# Values live in `products.custom_attributes` keyed by label, so every definition change is
# paired with a jsonb key rewrite. All of them lead with `custom_attributes ? :label`, the
# one condition the GIN index on that column can serve, so each statement touches only the
# products that actually hold the key rather than rewriting the table.
#
# Nothing here goes through the model: `CustomAttribute` has before_validation hooks that
# clear `options` and `units` on a type switch, which is exactly what the cartridge
# conversion below must not have happen mid-flight. The cache those callbacks would normally
# invalidate is cleared explicitly at the end instead.
class RenameCustomAttributeLabels < ActiveRecord::Migration[8.1]
  # Pure renames: same definition, same values, better name.
  #
  #   enclosure_type                       headphone enclosures (open/semi/closed) and speaker
  #                                        enclosures (sealed/ported/...) are different option
  #                                        sets, so both sides get a prefix.
  #   loudspeaker_frequency_response_range same unit and same meaning for headphones,
  #                                        subwoofers and tape decks, so the prefix comes off
  #                                        and the one definition is shared. This also adopts
  #                                        the `frequency_response_range` translation that has
  #                                        been sitting in en.yml with no attribute behind it.
  RENAMES = {
    'enclosure_type' => 'headphone_enclosure_type',
    'loudspeaker_frequency_response_range' => 'frequency_response_range'
  }.freeze

  # `mm-mc` as a third value of a single-select is a multi-select emulated by hand: it means
  # "both", not a third kind of cartridge. Converting to `options` says that directly, and
  # lets a stage that supports only one of the two stay one selection rather than two.
  CARTRIDGE_VALUE_MAP = { '1' => %w[1], '2' => %w[2], '3' => %w[1 2] }.freeze

  # power_amplifier_channel_type numbered {1: mono, 2: stereo}; the surviving definition
  # (formerly amplifier_channel_type) numbers {1: stereo, 2: dual-mono}. Only the ids move --
  # no product changes which channel configuration it claims.
  CHANNEL_VALUE_MAP = { '1' => '3', '2' => '1' }.freeze

  CHANNEL_OPTIONS = { '1' => 'stereo', '2' => 'dual-mono', '3' => 'mono' }.freeze
  CARTRIDGE_OPTIONS = { '1' => 'mm', '2' => 'mc' }.freeze

  def up
    RENAMES.each { |from, to| rename_label(from, to) }

    convert_cartridge_support
    merge_nominal_impedance
    merge_channel_configuration

    Rails.cache.delete('all_custom_attributes')
  end

  # The merges are one-way. Once `loudspeaker_nominal_impedance` and `nominal_impedance` are
  # one key, nothing in the row records which of the two a given product used to carry, and
  # the same is true of the two channel attributes. A `down` could recreate the definitions
  # but would have to guess at every value, so it would silently invent data rather than
  # restore it. Recovery is a restore, not a rollback.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def rename_label(from, to)
    say_with_time "#{from} -> #{to}" do
      execute(sql(<<~SQL, from: from, to: to))
        UPDATE products
        SET custom_attributes = (custom_attributes - :from)
                                || jsonb_build_object(:to, custom_attributes -> :from)
        WHERE custom_attributes ? :from
      SQL

      execute(sql('UPDATE custom_attributes SET label = :to WHERE label = :from', from: from, to: to))
    end
  end

  # turntable_cartridge_type -> supported_cartridge_types, single-select -> multi-select.
  #
  # The prefix was wrong twice over: the attribute is used by phono stages and step-up
  # transformers as much as by turntables, and it answers "what does this accept", where
  # `cartridge_type` answers "what is this". Those are different questions, so they keep
  # different names rather than being told apart by a category word.
  def convert_cartridge_support
    say_with_time 'turntable_cartridge_type -> supported_cartridge_types (option -> options)' do
      execute(sql(<<~SQL, cases: CARTRIDGE_VALUE_MAP.keys))
        UPDATE products
        SET custom_attributes = (custom_attributes - 'turntable_cartridge_type')
                                || jsonb_build_object('supported_cartridge_types',
                                                      #{cartridge_case_sql})
        WHERE custom_attributes ? 'turntable_cartridge_type'
          AND COALESCE(custom_attributes ->> 'turntable_cartridge_type', '') IN (:cases)
      SQL

      # Anything holding an id the definition never offered is dropped rather than carried
      # over: it cannot be displayed or filtered either way, and leaving the old key behind
      # would keep a label alive that no definition backs.
      drop_orphans = execute(
        "UPDATE products SET custom_attributes = custom_attributes - 'turntable_cartridge_type' " \
        "WHERE custom_attributes ? 'turntable_cartridge_type'"
      )
      report_orphans('turntable_cartridge_type', drop_orphans.cmd_tuples)

      execute(sql(<<~SQL, options: CARTRIDGE_OPTIONS.to_json))
        UPDATE custom_attributes
        SET label = 'supported_cartridge_types', input_type = 'options', options = :options::jsonb
        WHERE label = 'turntable_cartridge_type'
      SQL
    end
  end

  # Headphone impedance and speaker impedance are the same physical quantity in the same
  # unit; only the typical range differs, and the subcategory join already keeps the two
  # filter facets apart. `loudspeaker_minimum_impedance` stays -- that is a genuinely
  # different specification, not the same one under another name.
  def merge_nominal_impedance
    say_with_time 'loudspeaker_nominal_impedance -> nominal_impedance (merge)' do
      absorb_key('loudspeaker_nominal_impedance', 'nominal_impedance')
      merge_definitions('loudspeaker_nominal_impedance', 'nominal_impedance')
    end
  end

  # Two definitions asking the same question with arbitrarily different option sets. The
  # surviving one gains `mono` so it can answer for power amplifiers too, and keeps the
  # highlighted flag its power-amplifier half carried -- channel configuration is a key spec
  # there, and treating it as one everywhere is the point of merging.
  def merge_channel_configuration
    say_with_time 'amplifier_channel_type + power_amplifier_channel_type -> channel_configuration' do
      rename_label('amplifier_channel_type', 'channel_configuration')

      execute(sql(<<~SQL, options: CHANNEL_OPTIONS.to_json))
        UPDATE custom_attributes
        SET options = :options::jsonb, highlighted = TRUE
        WHERE label = 'channel_configuration'
      SQL

      absorb_key('power_amplifier_channel_type', 'channel_configuration', value_map: CHANNEL_VALUE_MAP)
      merge_definitions('power_amplifier_channel_type', 'channel_configuration')
    end
  end

  # Moves `from`'s value onto `to`, optionally renumbering it, and drops `from` either way.
  #
  # A product carrying both keys keeps the one already under `to`: the two only ever coexist
  # on a product sitting in subcategories from both sides of the merge, where the surviving
  # attribute's own value is the one its form was showing.
  def absorb_key(from, to, value_map: nil)
    value = if value_map
              "to_jsonb(#{case_sql("custom_attributes ->> '#{from}'", value_map)})"
            else
              "custom_attributes -> '#{from}'"
            end

    guard = if value_map
              "custom_attributes ? '#{to}' " \
              "OR COALESCE(custom_attributes ->> '#{from}', '') NOT IN (#{quoted_list(value_map.keys)})"
            else
              "custom_attributes ? '#{to}'"
            end

    result = execute(<<~SQL)
      UPDATE products
      SET custom_attributes = (custom_attributes - '#{from}')
                              || CASE WHEN #{guard} THEN '{}'::jsonb
                                      ELSE jsonb_build_object('#{to}', #{value}) END
      WHERE custom_attributes ? '#{from}'
    SQL

    say("#{result.cmd_tuples} product(s) moved from #{from} to #{to}", true)
  end

  # Subcategory links move before the loser is deleted, so an attribute stays applicable
  # everywhere either definition applied. ON CONFLICT covers the subcategories both were
  # already attached to.
  def merge_definitions(loser_label, winner_label)
    execute(sql(<<~SQL, loser: loser_label, winner: winner_label))
      INSERT INTO custom_attributes_sub_categories (custom_attribute_id, sub_category_id)
      SELECT winner.id, link.sub_category_id
      FROM custom_attributes_sub_categories link
      JOIN custom_attributes loser ON loser.id = link.custom_attribute_id AND loser.label = :loser
      CROSS JOIN custom_attributes winner
      WHERE winner.label = :winner
      ON CONFLICT DO NOTHING
    SQL

    execute(sql(<<~SQL, loser: loser_label))
      DELETE FROM custom_attributes_sub_categories
      WHERE custom_attribute_id IN (SELECT id FROM custom_attributes WHERE label = :loser)
    SQL

    execute(sql('DELETE FROM custom_attributes WHERE label = :loser', loser: loser_label))
  end

  def cartridge_case_sql
    branches = CARTRIDGE_VALUE_MAP.map do |from, to|
      "WHEN #{quote(from)} THEN #{quote(to.to_json)}::jsonb"
    end

    "CASE custom_attributes ->> 'turntable_cartridge_type' #{branches.join(' ')} END"
  end

  def case_sql(expression, mapping)
    branches = mapping.map { |from, to| "WHEN #{quote(from)} THEN #{quote(to)}" }

    "CASE #{expression} #{branches.join(' ')} END"
  end

  def quoted_list(values)
    values.map { |value| quote(value) }.join(', ')
  end

  def report_orphans(label, count)
    return if count.zero?

    say("#{count} product(s) held a #{label} id no definition offered; the value was dropped", true)
  end

  def sql(statement, binds)
    ActiveRecord::Base.send(:sanitize_sql_array, [statement, binds])
  end
end
