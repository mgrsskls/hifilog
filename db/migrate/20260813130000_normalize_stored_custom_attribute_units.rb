# frozen_string_literal: true

# Rewrites every numeric custom attribute value into its canonical unit.
#
# Filtering normalises a submitted range to the metric side of a unit pair and then matches on
# the stored `unit` string, but nothing ever normalised the stored side. A product whose weight
# was entered in pounds sits in the database as `{value: 2, unit: "lb"}` and is invisible to
# every weight filter: a kilogram query looks for `unit = 'kg'` and misses it, and a pound
# query is converted to kilograms first and misses it too. Its number is never converted
# either, so even a match would compare 2 against a column of kilograms.
#
# Product now normalises on write (see Product#normalize_custom_attribute_units); this is the
# same operation applied once to everything written before that existed.
#
# The rows to fix are found with a jsonpath predicate rather than a scan: `@?` is servable by
# the existing GIN index on products.custom_attributes, so the catalogue is narrowed to the
# handful of products actually holding a non-canonical unit before anything is loaded.
#
# Values are written with update_column, which skips validation, `updated_at` and PaperTrail on
# purpose. This is a correction of how a number was recorded, not an edit anyone made: it
# should not appear in a product's changelog, and it should not push products to the top of the
# catalogue's "recently updated" ordering.
class NormalizeStoredCustomAttributeUnits < ActiveRecord::Migration[8.1]
  def up
    # The definitions cache may predate the label migration that runs before this one, and
    # normalize_units reads it to find each attribute's input type.
    Rails.cache.delete('all_custom_attributes')

    converted = 0

    say_with_time 'Normalising stored custom attribute units' do
      Product.where(non_canonical_unit_predicate).find_each do |product|
        normalized = CustomAttribute.normalize_units(product.custom_attributes)
        next if normalized == product.custom_attributes

        product.update_column(:custom_attributes, normalized)
        converted += 1
      end

      converted
    end

    report(converted)
  end

  # The pre-migration unit and value are both overwritten in place, and nothing records which
  # products were touched, so there is nothing a `down` could read to put pounds back.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # `$.*` walks the top-level attribute entries; the filter keeps those whose `unit` is one
  # the conversion table would move. Built from UNIT_CONVERSIONS so adding a convertible unit
  # later cannot leave this migration's idea of the set behind.
  def non_canonical_unit_predicate
    units = CustomAttribute::UNIT_CONVERSIONS.keys
                                             .map { |unit| "@.unit == #{unit.inspect}" }
                                             .join(' || ')

    Arel.sql(
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        ['custom_attributes @? :path::jsonpath', { path: "$.* ? (#{units})" }]
      )
    )
  end

  def report(converted)
    return say('No product held a value in a non-canonical unit.') if converted.zero?

    say("#{converted} product(s) had at least one value rewritten into its canonical unit; " \
        'those products are now reachable by the numeric filters.')
  end
end
