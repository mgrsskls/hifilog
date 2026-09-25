# frozen_string_literal: true

# Tuning values for the "Similar Products" block. See docs/similar-products.md.
#
# All values are Ruby constants, not database data. Thus, you can review and change them in one
# file. When you change a value, also increase SimilarProducts::CACHE_VERSION. If you do not,
# cached lists keep the old order until they expire.
#
# Candidates that have exactly the same sub categories as the product always come first. In each
# of these two groups, the score sets the order. The score of a candidate is the sum of these
# parts:
#
#   1. Sub category overlap:  SUB_CATEGORY_WEIGHT * shared / (all sub categories of both)
#   2. Categorical attributes: weight * shared values / (all values of both)
#   3. Numeric classes:        weight, when both values are in the same class
#   4. Price band:             PRICE_WEIGHT for the same band, half of it for the next band
#
# A missing value on one side gives 0 points. It does not give a penalty. Thus, a candidate
# with more data can get more points.
module SimilarProducts::Weights
  # Points for a full sub category overlap. For partial matches, the overlap competes with the
  # attribute points: a strong attribute match can move a candidate with less overlap up.
  SUB_CATEGORY_WEIGHT = 100

  # Candidates with a lower score are not shown. The value is low on purpose: a candidate that
  # has 1 of 10 sub categories in common and no other match is below it.
  MIN_SCORE = 10

  # Weight of the price band part. Prices are compared only when both use the same currency.
  PRICE_WEIGHT = 2

  # Width of one price band on a log10 scale. 0.5 gives bands of approximately x3:
  # 100-316, 316-1000, 1000-3162, and so on.
  PRICE_BAND_WIDTH = 0.5

  # Categorical attributes (input types option, options and boolean), by label.
  #   3 = defines what the product is (for example tube or solid state)
  #   2 = important property
  #   1 = small detail
  # An attribute that is not in this list gives 0 points.
  ATTRIBUTES = {
    'amplifier_type' => 3,
    'cable_interconnect_type' => 3,
    'cartridge_type' => 3,
    'headphone_connection_type' => 3,
    'headphone_driver_type' => 3,
    'headphone_enclosure_type' => 3,
    'loudspeaker_amplification_type' => 3,
    'loudspeaker_enclosure_type' => 3,
    'turntable_drive_type' => 3,
    'channel_configuration' => 2,
    'loudspeaker_driver_configuration' => 2,
    'loudspeaker_driver_types' => 2,
    'turntable_operation_type' => 2,
    'assembly' => 1,
    'headphone_outputs' => 1,
    'input_connectors' => 1,
    'loudspeaker_bi_amping' => 1,
    'loudspeaker_bi_wiring' => 1,
    'output_connectors' => 1,
    'speaker_outputs' => 1,
    'supported_cartridge_types' => 1
  }.freeze

  # Numeric attributes, compared as classes and not as exact values.
  #   weight: points when both values are in the same class
  #   limits: class limits, ascending. A value that is equal to a limit is in the upper class.
  #   input:  for an attribute with inputs (a value per load impedance), the input to compare
  #
  # Dimensions, weight and sensitivity are not in this list on purpose. They are too specific to
  # a single product to make two products similar.
  NUMERIC_CLASSES = {
    # Low power (for example a small tube amplifier), medium power, high power.
    'amplifier_output_power' => { weight: 2, limits: [25, 100], input: 'ohm_8' },
    'headphone_amplifier_output_power' => { weight: 1, limits: [0.25, 1], input: 'ohm_32' },
    # 4 ohm loudspeakers, 8 ohm loudspeakers, low impedance headphones, high impedance headphones.
    'nominal_impedance' => { weight: 2, limits: [6, 16, 100] }
  }.freeze
end
