# frozen_string_literal: true

# Puts back the imperial figures that the product form converted on save.
#
# Until figures were stored in the unit the source states them in (docs/custom-attributes.md,
# "Two units"), a figure typed in pounds or inches was converted into the metric unit before save
# and stored with eight decimals: 33 lb became 14.96850821 kg. The conversion is an exact
# multiplication, so the typed figure can be read back: 14.96850821 kg is 33.00000000 lb.
#
# An entry is restored when both are true:
#
#   * The metric figure has more decimals than a brand states in that unit (MAX_STATED_DECIMALS).
#     Brands state "0.287 kg" but not four decimals, and "20.5 cm" but not two. This protects a
#     stated figure that is by chance an exact conversion: 127 cm is exactly 50 in, and 25.4 cm is
#     exactly 10 in, but neither has more than one decimal.
#   * Converted back, it gives an imperial figure with at most two decimals.
#
# The threshold depends on the unit, because the factors differ. 0.45359237 turns every pound
# figure into a long number (33 lb is 14.96850821 kg), but 2.54 turns a whole inch figure into a
# figure with two decimals at most (17 in is 43.18 cm).
#
# For a multi input value, one input must show the precision and every input must convert back,
# because all inputs share one unit: 5 in is 12.7 cm and shows no conversion by itself.
#
# Written with update_column, which skips validation, `updated_at` and PaperTrail, like
# NormalizeStoredCustomAttributeUnits: this corrects how a figure was recorded, it is not an edit
# anyone made.
class RestoreStatedImperialFigures < ActiveRecord::Migration[8.1]
  TOLERANCE = 1e-6
  # The most decimals a brand states in each metric unit of a pair. A figure with more is a
  # conversion.
  MAX_STATED_DECIMALS = { 'kg' => 3, 'cm' => 1, 'm' => 2 }.freeze

  def up
    restored = 0

    say_with_time 'Restoring stated imperial figures' do
      pair_labels = pair_definitions

      Product.where.not(custom_attributes: nil).find_each do |product|
        values = product.custom_attributes
        next unless values.is_a?(Hash)

        changed = values.to_h do |label, entry|
          [label, pair_labels.include?(label) ? restored_entry(entry) : entry]
        end
        next if changed == values

        product.update_column(:custom_attributes, changed) # rubocop:disable Rails/SkipsModelValidations
        restored += 1
      end

      restored
    end

    say("#{restored} product(s) had a figure restored to the imperial unit it was typed in.")
  end

  # The converted metric figures are gone once restored, but they can be computed again.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Labels of the definitions whose two units are a pair.
  def pair_definitions
    CustomAttribute.where(input_type: 'number').select(&:unit_pair?).map(&:label)
  end

  def restored_entry(entry)
    return entry unless entry.is_a?(Hash) && entry['second'].nil?

    imperial, factor = CustomAttribute::UNIT_CONVERSIONS.find { |_from, (to, _factor)| to == entry['unit'] }
                                                        &.then { |from, (_to, multiplier)| [from, multiplier] }
    return entry if imperial.nil?

    value = restored_value(entry['value'], factor, MAX_STATED_DECIMALS[entry['unit']])
    value.nil? ? entry : entry.merge('value' => value, 'unit' => imperial)
  end

  def restored_value(value, factor, max_decimals)
    numbers = value.is_a?(Hash) ? value.values : [value]
    return unless max_decimals && numbers.all?(Numeric)
    return unless numbers.any? { |number| decimals(number) > max_decimals }

    if value.is_a?(Hash)
      restored = value.transform_values { |number| imperial_number(number, factor) }
      restored.values.all? ? restored : nil
    else
      imperial_number(value, factor)
    end
  end

  # The imperial figure `number` converts back to, or nil when that has more than two decimals.
  def imperial_number(number, factor)
    imperial = number / factor
    rounded = imperial.round(2)
    rounded if (imperial - rounded).abs < TOLERANCE
  end

  def decimals(number)
    BigDecimal(number.to_s).to_s('F').sub(/\.0+\z/, '').split('.', 2)[1].to_s.length
  end
end
