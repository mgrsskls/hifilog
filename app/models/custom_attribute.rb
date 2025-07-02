class CustomAttribute < ApplicationRecord
  VALID_UNITS = %w[in cm lb kg db w ohm hz db_1w_1m db_283v_1m].freeze
  VALID_INPUTS = %w[w h l min max].freeze

  has_and_belongs_to_many :sub_categories
  enum :input_type, {
    number: 'number',
    option: 'option',
    options: 'options',
  }, suffix: true

  validates :label, presence: true, uniqueness: true
  validate :units_must_be_valid
  validate :inputs_must_be_valid

  before_validation do
    self.units = units.compact_blank if units.is_a?(Array)
    self.inputs = inputs.compact_blank if inputs.is_a?(Array)
  end

  before_save do
    if options.present?
      self.options = JSON.parse(options) if options.is_a?(String)
    else
      self.options = nil
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

  # :nocov:
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
  # :nocov:
end
