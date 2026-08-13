# frozen_string_literal: true

class CustomAttribute < ApplicationRecord
  VALID_UNITS = %w[in cm lb kg db w ohm hz db_1w_1m db_283v_1m db_mw].freeze
  VALID_INPUTS = %w[w h l min max].freeze

  # after_commit ensures the DB transaction is finished before we clear cache
  after_commit :clear_cache

  has_and_belongs_to_many :sub_categories
  enum :input_type, {
    number: 'number',
    option: 'option',
    options: 'options',
    boolean: 'boolean'
  }, suffix: true

  validates :label, presence: true, uniqueness: true
  validates :highlighted, presence: true
  validate :units_must_be_valid
  validate :inputs_must_be_valid

  before_validation do
    self.units = units.compact_blank if units.is_a?(Array)
    self.inputs = inputs.compact_blank if inputs.is_a?(Array)
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

  def self.all_cached
    Rails.cache.fetch('all_custom_attributes') do
      all.to_a # .to_a executes the query and stores the array
    end
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

    errors.add(:units, "contain invalid values: #{invalid.join(', ')}") if invalid.any?
  end

  # simplecov:disable
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      sub_categories
      sub_categories_id
      label
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # simplecov:enable

  private

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

  def clear_cache
    Rails.cache.delete('all_custom_attributes')
  end
end
