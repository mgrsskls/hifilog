# frozen_string_literal: true

# How one entry of a number attribute reads: a line for each input (or one line), and on each
# line the figures in the order they are shown.
#
# A stated figure is shown as stored. When the definition offers both units of the pair and the
# entry states only one of the two figures, the other one follows, converted and rounded to the significant
# figures of the stated one (CustomAttribute.converted_figure). "15 kg" reads "15 kg / 33 lb",
# "15 kg, second 33 lb" reads the same, and "33 lb" reads "33 lb / 15 kg".
#
# One class for all display sites -- the product page, the product card, the changelog, the admin
# activity list and the import candidate view -- because a second figure that four of them show
# and the fifth forgets makes a change of that figure look like no change at all. The sites only
# decide how a unit is rendered. See docs/custom-attributes.md, "Two units".
class CustomAttributeReading
  Figure = Data.define(:number, :unit)
  Line = Data.define(:input, :figures)

  # `definition` can be nil: the changelog shows entries of definitions that were deleted since.
  def initialize(definition, entry)
    @definition = definition
    @entry = entry.is_a?(Hash) ? entry.stringify_keys : {}
  end

  # One line for each input that either figure states: a contributor can fill in more inputs in
  # the imperial row than in the metric row.
  def lines
    value = @entry['value']

    if value.is_a?(Hash)
      second = @entry['second']
      second_value = second['value'] if second.is_a?(Hash)
      inputs = value.keys | (second_value.is_a?(Hash) ? second_value.keys : [])

      inputs.map { |input| Line.new(input:, figures: figures(input)) }
    elsif value.present?
      [Line.new(input: nil, figures: figures(nil))]
    else
      []
    end
  end

  # The one figure to show where there is room for one reading only, on the product card: the
  # metric one, stated or converted, so that a list never mixes "15 kg" and "33 lb".
  def primary_figure
    figures = lines.first&.figures || []

    figures.find { |figure| !CustomAttribute.imperial_unit?(figure.unit) } || figures.first
  end

  private

  def figures(input)
    stated = stated_numbers(input)
    shown = stated.map { |unit, number| Figure.new(number: format(number), unit:) }
    return shown unless @definition && stated.size == 1

    unit, number = stated.first
    return shown unless @definition.partner_offered?(unit)

    other, converted = CustomAttribute.converted_figure(number, unit)

    shown << Figure.new(number: format(converted), unit: other)
  end

  # unit => number of this input. An entry without a unit reads in the definition's first unit,
  # as it always has.
  def stated_numbers(input)
    entry = @entry['unit'].present? ? @entry : @entry.merge('unit' => @definition&.units&.first)
    figures = entry['unit'].present? ? CustomAttribute.stated_figures(entry) : { nil => entry['value'] }

    figures.filter_map do |unit, value|
      number = numeric(input ? value.try(:[], input) : value)
      [unit, number] if number
    end
  end

  # Import candidates can hold a figure as a string.
  def numeric(value)
    value.is_a?(Numeric) ? value : Float(value.to_s, exception: false)
  end

  def format(number)
    ActiveSupport::NumberHelper.number_to_rounded(number, precision: 4, strip_insignificant_zeros: true)
  end
end
