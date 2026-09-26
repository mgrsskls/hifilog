# frozen_string_literal: true

# Adds the second stated figure to pending import candidates, read from the snippet the importer
# stored as provenance ("Weight: 16 kg / 35 lbs"). A one-off for the candidates that were loaded
# before an entry could hold two figures; it reads no page. See docs/import.md, "Two units".
#
# A candidate gets a second figure only when the snippet is unambiguous: it states the stored
# figure, and exactly one figure (or one set of dimensions) in the other unit of the pair. When
# the two figures disagree (CustomAttribute.figures_agree?), the candidate gets a warning instead,
# and the reviewer decides: a brand's own figures sometimes disagree, and nobody can tell from
# the snippet which one is wrong.
#
# Idempotent: an entry that already has a second figure is skipped, and a warning is added once.
class ImportCandidateSecondFigures
  NUMBER = '\d+(?:[.,]\d+)?'
  WEIGHT = /(#{NUMBER})\s*(kgs?|kilograms?|g|grams?|gr|lbs?|pounds?)\b/i
  DIMENSION_UNIT = '(mm|cm|inch(?:es)?|in\b|"|″|”)'
  SEPARATOR = '\s*[x×*]\s*'
  DIMENSION = "(#{NUMBER})\\s*#{DIMENSION_UNIT}".freeze
  DIMENSIONS = /#{DIMENSION}?#{SEPARATOR}#{DIMENSION}?#{SEPARATOR}#{DIMENSION}/i
  TOLERANCE = 1e-6

  Result = Data.define(:candidate, :label, :outcome, :detail)

  def initialize(scope: ImportCandidate.where(status: 'pending'))
    @scope = scope
    @definitions = CustomAttribute.all_cached.select(&:unit_pair?).index_by(&:label)
  end

  # Every candidate entry that would change, with what happens to it. Writes only with apply: true.
  def call(apply: false)
    results = []

    @scope.find_each do |candidate|
      candidate_results = @definitions.filter_map { |label, definition| result_for(candidate, label, definition) }
      next if candidate_results.empty?

      write(candidate, candidate_results) if apply
      results.concat(candidate_results)
    end

    results
  end

  private

  def result_for(candidate, label, definition)
    entry = candidate.custom_attributes&.dig(label)
    return unless entry.is_a?(Hash) && entry['second'].nil? && definition.units.include?(entry['unit'])

    snippet = candidate.provenance.dig("custom_attributes.#{label}", 'snippet').to_s
    other_unit = CustomAttribute.partner_unit(entry['unit'])
    other_value = definition.inputs.any? ? other_dimensions(snippet, entry) : other_weight(snippet, entry)
    return if other_value.nil?

    if CustomAttribute.figures_agree?(entry['value'], entry['unit'], other_value, other_unit)
      Result.new(candidate:, label:, outcome: :added, detail: { 'value' => other_value, 'unit' => other_unit })
    else
      Result.new(candidate:, label:, outcome: :conflict,
                 detail: conflict_warning(label, entry, other_value, other_unit))
    end
  end

  # The one figure in the other unit, when the snippet also states the stored figure.
  def other_weight(snippet, entry)
    figures = snippet.scan(WEIGHT).map { |number, unit| weight_figure(number, unit) }
    return unless figures.any? { |unit, value| unit == entry['unit'] && same?(value, entry['value']) }

    others = figures.reject { |unit, _value| unit == entry['unit'] }.map(&:last).uniq
    others.first if others.one?
  end

  def weight_figure(number, unit)
    value = number.tr(',', '.').to_f
    case unit.downcase
    when /\Ak/ then ['kg', value]
    when /\A(lb|pound)/ then ['lb', value]
    else ['kg', (value / 1000).round(8)]
    end
  end

  # The one set of dimensions in the other unit, mapped onto the stored inputs by position: the
  # snippet lists both sets in the same order ("30 × 30 × 33 cm / 12 × 12 × 13"").
  def other_dimensions(snippet, entry)
    stored = entry['value']
    return unless stored.is_a?(Hash) && stored.values.all?(Numeric)

    sets = snippet.scan(DIMENSIONS).map { |match| dimension_set(match) }
    own = sets.select { |unit, numbers| unit == entry['unit'] && positions(stored, numbers) }
    others = sets.reject { |unit, _numbers| unit == entry['unit'] }
    return unless own.one? && others.one?

    stored.keys.zip(positions(stored, own.first.last)).to_h { |input, index| [input, others.first.last[index]] }
  end

  # [unit, [three numbers]], millimetres read as centimetres, as the importer stored them.
  def dimension_set(match)
    numbers = [match[0], match[2], match[4]].map { |number| number.tr(',', '.').to_f }
    unit = match.values_at(1, 3, 5).compact.last.downcase

    case unit
    when 'mm' then ['cm', numbers.map { |number| (number / 10).round(8) }]
    when 'cm' then ['cm', numbers]
    else ['in', numbers]
    end
  end

  # For each stored input, the position of its figure in `numbers`, or nil when the stored figures
  # are not exactly these numbers.
  def positions(stored, numbers)
    free = numbers.each_index.to_a
    indexes = stored.values.map do |value|
      index = free.find { |position| same?(numbers[position], value) }
      free.delete(index)
    end
    indexes.all? ? indexes : nil
  end

  def same?(number, other)
    (number - other).abs <= TOLERANCE * [number.abs, other.abs, 1].max
  end

  def conflict_warning(label, entry, other_value, other_unit)
    "#{label}: the stated figures disagree (#{figure_text(entry['value'], entry['unit'])} / " \
      "#{figure_text(other_value, other_unit)}), no second figure added"
  end

  def figure_text(value, unit)
    numbers = (value.is_a?(Hash) ? value.values : [value]).map do |number|
      ActiveSupport::NumberHelper.number_to_rounded(number, precision: 4, strip_insignificant_zeros: true)
    end
    "#{numbers.join(' × ')} #{unit}"
  end

  # update_columns: a correction of how the importer recorded the candidate, not a review. It
  # must not set `edited_at`, which marks a candidate as changed by a person.
  def write(candidate, results)
    attributes = candidate.custom_attributes.deep_dup
    warnings = Array(candidate.warnings).dup

    results.each do |result|
      if result.outcome == :added
        attributes[result.label] = attributes[result.label].merge('second' => result.detail)
      else
        warnings << result.detail unless warnings.include?(result.detail)
      end
    end

    # rubocop:disable Rails/SkipsModelValidations
    candidate.update_columns(custom_attributes: CustomAttribute.order_figures(attributes), warnings:)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
