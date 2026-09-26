# frozen_string_literal: true

# dB@1W/1m and dB@2.83V/1m were never two units. They are one unit, dB, measured under two
# conditions, and a definition may offer two units only when UNIT_CONVERSIONS pairs them -- which
# these are not, because no factor exists between them. Now that a qualifier can hold the
# condition, the definition holds one unit and two qualifiers.
#
# The definition is a data row rather than code, so it is rewritten here and not by hand in
# ActiveAdmin: the definition and the values it describes have to change in one transaction. A
# value still saying `db_1w_1m` under a definition offering only `db` is not merely untidy, it is
# unfilterable -- the filter normalises a submitted range and then compares the stored unit string.
#
# WHICH OLD UNITS ARE EVIDENCE, AND WHICH ARE A FALLBACK
#
# `db_283v_1m` is always evidence. Both writers of it looked at something: the product form's unit
# radio buttons start unselected, so a unit saved from the form was chosen on purpose, and
# `specs.py` wrote this one only after finding a 2.83 V marker in the source line. Checking 892
# production candidates confirmed it -- every stored `db_283v_1m` has that marker in its snippet.
#
# `db_1w_1m` is evidence from the form and a FALLBACK from the importer. `specs.py` used to end
# `else "db_1w_1m"`, so a sheet stating no reference at all got the same answer as one stating
# 1 W/1 m. In production that was 134 of 157 candidates. Deriving a condition from those would
# claim a measurement nobody published, which §4.1 of the documentation refuses.
#
# So a snippet decides where there is one:
#
#   * `import_candidates` keeps the source line in
#     `provenance -> 'custom_attributes.loudspeaker_sensitivity' ->> 'snippet'`. A `db_1w_1m`
#     candidate gets the qualifier only when that line names a watt reference. No snippet means no
#     evidence, because every candidate unit came from `specs.py`.
#   * A product's unit came from the form unless an import wrote it, so `db_1w_1m` gets the
#     qualifier UNLESS the candidate it was promoted from has a snippet that names no watt
#     reference. That is a negative test on purpose: absence of a candidate is not absence of
#     evidence, it is a form entry.
#
# No unit at all is no condition either way. The display falls back to `units.first`, which shows a
# condition nobody entered, so that fallback is not written into the data.
#
# `import_candidates` is rewritten as well, and not only `products`. A candidate extracted before
# this migration still holds the old unit, and ImportPromotion copies `custom_attributes` into the
# new product verbatim -- it does not pass through the product form. Promoting such a candidate
# would create a product carrying a unit its definition no longer offers, which no filter can
# reach.
class MoveLoudspeakerSensitivityToQualifiers < ActiveRecord::Migration[8.1]
  LABEL = 'loudspeaker_sensitivity'
  NEW_UNIT = 'db'
  OLD_UNITS = %w[db_1w_1m db_283v_1m].freeze
  QUALIFIERS = %w[drive_1w_1m drive_283v_1m].freeze

  # A watt reference as the source prints it: "1 W", "1W/1m", "dB/W/m".
  #
  # POSIX classes rather than `\s`: Ruby reads `\s` in an interpolating heredoc as a plain space, so
  # the regex would say something slightly different from what it looks like. The class brings its
  # own hazard -- `[[:space:]]` looks like a `:space` bind variable to Rails -- which is why nothing
  # in this migration goes through bind substitution. See the note above set_unit_and_qualifier.
  WATT_MARKER = '1[[:space:]]*w|db[[:space:]]*/[[:space:]]*w[[:space:]]*/[[:space:]]*m'
  # "2.83 V", "2,83V", the rounded "2.8 V". The same reading specs.py takes.
  VOLTAGE_MARKER = '2[.,]83?[[:space:]]*v'

  def up
    # The unit itself is evidence: nothing but a 2.83 V marker or a form choice writes it.
    %w[products import_candidates].each do |table|
      set_unit_and_qualifier(table, from_unit: 'db_283v_1m', qualifier: 'drive_283v_1m')
    end

    # `db_1w_1m` over a source line that names 2.83 V and no watt reference. specs.py read only the
    # value side of a line, so "Sensitivity (2.83Vrms/1m): 84dB" came out as the watt fallback. The
    # source line says otherwise, so it is corrected here rather than by hand afterwards.
    set_unit_and_qualifier('import_candidates', from_unit: 'db_1w_1m', qualifier: 'drive_283v_1m',
                                                condition: own_snippet(names: VOLTAGE_MARKER,
                                                                       but_not: WATT_MARKER))
    set_unit_and_qualifier('products', from_unit: 'db_1w_1m', qualifier: 'drive_283v_1m',
                                       condition: promoted_from_candidate_whose_snippet(
                                         names: VOLTAGE_MARKER, but_not: WATT_MARKER
                                       ))

    # A watt reference that the source really states.
    set_unit_and_qualifier('import_candidates', from_unit: 'db_1w_1m', qualifier: 'drive_1w_1m',
                                                condition: own_snippet(names: WATT_MARKER))
    set_unit_and_qualifier('products', from_unit: 'db_1w_1m', qualifier: 'drive_1w_1m',
                                       condition: "NOT #{promoted_from_candidate_whose_snippet(
                                         but_not: WATT_MARKER
                                       )}")

    # Whatever is left: the figure stays, the condition stays unstated.
    %w[products import_candidates].each { |table| set_unit_only(table, from_unit: 'db_1w_1m') }

    set_definition(units: [NEW_UNIT], qualifiers: QUALIFIERS)
    clear_definition_cache
  end

  def down
    QUALIFIERS.zip(OLD_UNITS).each do |qualifier, unit|
      %w[products import_candidates].each { |table| restore_unit(table, qualifier:, unit:) }
    end

    # An entry left with `db` and no qualifier has no old unit to go back to. It is one of three
    # things -- a figure whose source stated no reference, a figure with no unit to begin with, or
    # one entered after this migration -- and nothing in the row says which. The unit key is
    # removed rather than guessed.
    #
    # So `down` is not exactly `up` reversed: a row that held the old `db_1w_1m` fallback comes back
    # with no unit at all. That is deliberate. Restoring `db_1w_1m` would put back an assumption,
    # and it would put it on rows that never had it.
    %w[products import_candidates].each { |table| drop_new_unit(table) }

    set_definition(units: OLD_UNITS, qualifiers: [])
    clear_definition_cache
  end

  private

  # EVERY literal here is quoted and spliced in; nothing goes through named or positional binds.
  #
  # That is not a style choice. This statement contains three things Rails' bind substitution reads
  # as its own: `?` is the jsonb "has key" operator but also a positional placeholder, `#-` is the
  # delete-path operator, and `[[:space:]]` in the regex below looks like a `:space` bind. Each was
  # found the hard way. Quoting the values and calling `execute` with finished SQL removes the whole
  # class of problem rather than dodging the next member of it.
  #
  # jsonb_set writes the whole entry back with the unit replaced and the qualifier added, so the
  # value and anything else in the entry survive untouched. The WHERE leads with `?`, which the GIN
  # index on custom_attributes can serve.
  def set_unit_and_qualifier(table, from_unit:, qualifier:, condition: nil)
    execute(<<~SQL.squish)
      UPDATE #{table}
      SET custom_attributes = jsonb_set(
        jsonb_set(custom_attributes, ARRAY[#{quoted_label}, 'unit'], to_jsonb(#{quote(NEW_UNIT)}::text)),
        ARRAY[#{quoted_label}, 'qualifier'], to_jsonb(#{quote(qualifier)}::text)
      )
      WHERE custom_attributes ? #{quoted_label}
        AND custom_attributes -> #{quoted_label} ->> 'unit' = #{quote(from_unit)}
        #{"AND #{condition}" if condition}
    SQL
  end

  # Runs after the qualifier passes, so it only reaches the rows they left behind: the unit moves to
  # `db` and no condition is written.
  def set_unit_only(table, from_unit:)
    execute(<<~SQL.squish)
      UPDATE #{table}
      SET custom_attributes =
        jsonb_set(custom_attributes, ARRAY[#{quoted_label}, 'unit'], to_jsonb(#{quote(NEW_UNIT)}::text))
      WHERE custom_attributes ? #{quoted_label}
        AND custom_attributes -> #{quoted_label} ->> 'unit' = #{quote(from_unit)}
    SQL
  end

  # A test on a candidate's own source line, for a query on import_candidates itself.
  #
  # No snippet gives '', which matches nothing. For a candidate that is the right answer: every
  # candidate unit came from specs.py, so silence in the snippet is silence in the source.
  def own_snippet(names:, but_not: nil)
    snippet = "COALESCE(provenance -> #{quote(provenance_key)} ->> 'snippet', '')"
    test = "#{snippet} ~* #{quote(names)}"
    test += " AND #{snippet} !~* #{quote(but_not)}" if but_not

    test
  end

  # The same test against the source line of the candidate a product was promoted from.
  #
  # The provenance entry has to EXIST. A product with no candidate, or a candidate that recorded
  # nothing for this attribute, says nothing about the product's unit -- that unit came from the
  # form, where no radio starts selected, so it was chosen on purpose. Treating a missing entry as
  # "names no watt reference" would throw such a choice away: promote a candidate that had no
  # sensitivity, let a contributor fill it in afterwards, and the condition would vanish here.
  def promoted_from_candidate_whose_snippet(names: nil, but_not: nil)
    snippet = "ic.provenance -> #{quote(provenance_key)} ->> 'snippet'"
    tests = ["ic.provenance ? #{quote(provenance_key)}"]
    tests << "#{snippet} ~* #{quote(names)}" if names
    tests << "#{snippet} !~* #{quote(but_not)}" if but_not

    <<~SQL.squish
      EXISTS (
        SELECT 1 FROM import_candidates ic
        WHERE ic.product_id = products.id AND #{tests.join(' AND ')}
      )
    SQL
  end

  # `#-` deletes a path from a jsonb value, so the qualifier goes and the unit comes back.
  def restore_unit(table, qualifier:, unit:)
    execute(<<~SQL.squish)
      UPDATE #{table}
      SET custom_attributes =
        jsonb_set(custom_attributes, ARRAY[#{quoted_label}, 'unit'], to_jsonb(#{quote(unit)}::text))
        #- ARRAY[#{quoted_label}, 'qualifier']
      WHERE custom_attributes ? #{quoted_label}
        AND custom_attributes -> #{quoted_label} ->> 'qualifier' = #{quote(qualifier)}
    SQL
  end

  def drop_new_unit(table)
    execute(<<~SQL.squish)
      UPDATE #{table}
      SET custom_attributes = custom_attributes #- ARRAY[#{quoted_label}, 'unit']
      WHERE custom_attributes ? #{quoted_label}
        AND custom_attributes -> #{quoted_label} ->> 'unit' = #{quote(NEW_UNIT)}
    SQL
  end

  # Raw SQL rather than the model: CustomAttribute validates its label against the locale file and
  # guards the related products graph, and neither has anything to say about this rewrite. The row
  # may be absent in an environment with no catalogue data, which is not an error.
  def set_definition(units:, qualifiers:)
    execute(<<~SQL.squish)
      UPDATE custom_attributes
      SET units = #{quote(pg_array(units))}, qualifiers = #{quote(pg_array(qualifiers))}
      WHERE label = #{quoted_label}
    SQL
  end

  # The definition set is cached, and this process is not the one serving requests.
  #
  # With a per-process store -- :memory_store, which development uses whenever
  # tmp/caching-dev.txt exists -- this delete only clears the migration's own copy. A running
  # server goes on rendering the product form from the units it loaded before, so it keeps
  # offering dB@1W/1m and dB@2.83V/1m after the column says otherwise. Production's
  # :mem_cache_store is shared between processes, so there the delete lands.
  def clear_definition_cache
    Rails.cache.delete('all_custom_attributes')

    return unless Rails.cache.is_a?(ActiveSupport::Cache::MemoryStore)

    say 'This environment caches definitions per process, so a running server still holds the ' \
        'previous units. Restart it to see the change on the product form.'
  end

  def pg_array(values)
    "{#{values.join(',')}}"
  end

  def provenance_key
    "custom_attributes.#{LABEL}"
  end

  def quoted_label
    quote(LABEL)
  end

  # The migration's own connection, not ActiveRecord::Base's: Rails 8 wants a leased connection for
  # that, and this one is already in hand.
  def quote(value)
    connection.quote(value)
  end
end
