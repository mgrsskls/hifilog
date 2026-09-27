# frozen_string_literal: true

# Fills empty specifications of existing products from the brand websites that the brand importer
# crawled (docs/import.md). Only the products for which an import candidate matched the brand and
# the name, and only the figures that the page states outright.
#
# What was left out on purpose:
#
#   * Prices. The catalogue holds the launch price (docs/contribution-guidelines.md). A shop shows
#     today's price, often in a regional currency, so it is not evidence of the launch price.
#   * Conditions a page does not state. "98 dB" gets no drive qualifier, "20 W per channel" gets no
#     THD qualifier and no load unless the page names one. An assumed condition is invented data.
#   * Output power of tube amplifiers with 4 and 8 ohm taps, where the page gives one figure for
#     both, and headphone amplifier power quoted at gain settings instead of at 32 or 300 ohm.
#   * Shipping weights ("35 lbs. each in a shipping box").
#   * Figures that disagree with what the product already has. Those stay as they are.
#
# A label that already has a value is never touched, so a figure a person entered wins. A product
# whose brand or name differs from the one below is skipped, because the ids are the ids of the
# production database. Option values are written as keys and resolved to ids at run time, like
# lib/tasks/custom_attributes.rake does.
#
# Written through the model, not with update_column: this is new information about a product, not a
# correction of how a figure was stored. So the product validations run, the product changelog shows
# the change with the source as its comment, and the completeness score is recalculated.
class AddScrapedSpecificationsToProducts < ActiveRecord::Migration[8.1]
  SPECIFICATIONS = [
    {
      id: 2, brand: 'bluesound', name: 'Node',
      source: 'https://www.bluesound.com/products/node',
      values: { 'output_connectors' => %w[rca spdif_coaxial toslink] }
    },
    {
      id: 7, brand: 'feliks-audio', name: 'Elise',
      source: 'https://feliksaudio.pl/product/elise/',
      values: { 'headphone_outputs' => %w[jack_6_35mm] }
    },
    {
      id: 52, brand: 'feliks-audio', name: 'Euforia Evo',
      source: 'https://feliksaudio.pl/product/euforia-anniversary-copy/',
      values: { 'headphone_outputs' => %w[jack_6_35mm] }
    },
    {
      id: 54, brand: 'feliks-audio', name: 'Arioso 300B',
      source: 'https://feliksaudio.pl/product/arioso/',
      values: { 'input_connectors' => %w[rca] }
    },
    {
      id: 150, brand: 'cayin', name: 'HA-6A',
      source: 'https://cayin.com/produkt/cayin-ha-6a_r%c3%b6hren-kopfh%c3%b6rerverst%c3%a4rker/',
      values: {
        'weight' => { 'unit' => 'kg', 'value' => 19.5 },
        'dimensions' => { 'unit' => 'cm', 'value' => { 'w' => 36.0, 'l' => 32.2, 'h' => 19.7 } },
        'input_connectors' => %w[rca xlr],
        'headphone_outputs' => %w[jack_4_4mm jack_6_35mm xlr_4pin]
      }
    },
    {
      id: 151, brand: 'cayin', name: 'HA-3A',
      source: 'https://cayin.com/produkt/cayin-ha-3a_roehren-kopfhoererverstaerker/',
      values: {
        'weight' => { 'unit' => 'kg', 'value' => 12.0 },
        'dimensions' => { 'unit' => 'cm', 'value' => { 'w' => 30.6, 'l' => 26.0, 'h' => 17.0 } },
        'input_connectors' => %w[rca xlr],
        'headphone_outputs' => %w[jack_4_4mm jack_6_35mm xlr_4pin]
      }
    },
    {
      id: 519, brand: 'omega-speaker-systems', name: 'Junior 8 XRS',
      source: 'https://omegaloudspeakers.com/products/junior-8xrs',
      values: {
        'loudspeaker_sensitivity' => { 'unit' => 'db', 'value' => 98.0 },
        'nominal_impedance' => { 'value' => 8.0 },
        'frequency_response_range' => { 'value' => { 'min' => 38.0, 'max' => 20_000.0 } },
        'dimensions' => { 'unit' => 'in', 'value' => { 'w' => 12.0, 'l' => 7.0, 'h' => 38.0 } },
        'loudspeaker_driver_configuration' => 'full_range'
      }
    },
    {
      # No driver configuration: the page says "Crossover: None on the main driver", which leaves
      # open whether there is a second one.
      id: 520, brand: 'omega-speaker-systems', name: 'Super 8 XRS',
      source: 'https://omegaloudspeakers.com/products/super-8xrs',
      values: {
        'loudspeaker_sensitivity' => { 'unit' => 'db', 'value' => 98.0 },
        'nominal_impedance' => { 'value' => 8.0 },
        'frequency_response_range' => { 'value' => { 'min' => 35.0, 'max' => 20_000.0 } },
        'dimensions' => { 'unit' => 'in', 'value' => { 'w' => 14.0, 'l' => 7.5, 'h' => 38.0 } }
      }
    },
    {
      id: 529, brand: 'cayin', name: 'CS-6PH',
      source: 'https://cayin.com/produkt/cayin-cs-6ph-phono-vorverstaerker/',
      values: {
        'weight' => { 'unit' => 'kg', 'value' => 11.5 },
        'dimensions' => { 'unit' => 'cm', 'value' => { 'w' => 36.0, 'l' => 30.95, 'h' => 17.7 } }
      }
    },
    {
      id: 1307, brand: 'henry-audio', name: 'DA 256',
      source: 'https://www.henryaudio.com/products/da-256',
      values: {
        'input_connectors' => %w[usb_c usb_b spdif_coaxial toslink],
        'dimensions' => { 'unit' => 'cm', 'value' => { 'w' => 17.3, 'l' => 15.0, 'h' => 4.5 } }
      }
    },
    {
      id: 1342, brand: 'scheu-analog', name: 'Diamond',
      source: 'https://www.scheu-analog.de/product-page/diamond',
      values: { 'weight' => { 'unit' => 'kg', 'value' => 18.0 } }
    },
    {
      id: 1343, brand: 'scheu-analog', name: 'Cello',
      source: 'https://www.scheu-analog.de/product-page/cello',
      values: {
        'weight' => { 'unit' => 'kg', 'value' => 7.0 },
        'dimensions' => { 'unit' => 'cm', 'value' => { 'w' => 42.5, 'l' => 34.0, 'h' => 17.0 } }
      }
    },
    {
      id: 1604, brand: 'sono-vera', name: 'B300',
      source: 'https://sono-vera.com/product/b300-loudspeaker/',
      values: { 'woofer_size' => { 'unit' => 'in', 'value' => 10.0 } }
    },
    {
      id: 1637, brand: 'layer-audio-design', name: 'Gen-300B',
      source: 'https://www.layeraudiodesign.com/product-page/copy-of-gen-300b-integrated-amplifier',
      values: {
        'channel_configuration' => 'stereo',
        'amplifier_output_power' => { 'unit' => 'w', 'value' => { 'ohm_8' => 10.0 } },
        'amplifier_class' => 'class_a',
        'input_connectors' => %w[rca]
      }
    },
    {
      # No sensitivity: the two pages of this model state 105 and 100 dB/mW. Both state the rest.
      id: 1675, brand: 'hisenior', name: 'Mega5EST',
      source: 'https://www.hisenior-iem.com/products/mega5est',
      values: {
        'frequency_response_range' => { 'value' => { 'min' => 10.0, 'max' => 50_000.0 } },
        'nominal_impedance' => { 'value' => 25.0 },
        'headphone_connection_type' => 'wired'
      }
    },
    {
      id: 1680, brand: 'bandoss', name: 'Avija',
      source: 'https://bandossheadphones.com/product/bandoss-avija/',
      values: { 'weight' => { 'unit' => 'g', 'value' => 480.0 } }
    },
    {
      # "10 Watts per channel ... The standard output is 8 ohms".
      id: 1802, brand: 'analog-ethos', name: 'Sereno 300B',
      source: 'https://www.analogethos.com/product-page/sereno-300b-mono-block',
      values: { 'amplifier_output_power' => { 'unit' => 'w', 'value' => { 'ohm_8' => 10.0 } } }
    },
    {
      # "Capacity: 50 W sinus", the continuous power the loudspeaker takes.
      id: 1835, brand: 'voxativ', name: 'Zeth',
      source: 'https://www.voxativ.berlin/products/zeth',
      values: { 'loudspeaker_rms_power' => { 'value' => 50.0 } }
    },
    {
      id: 1836, brand: 'linear-tube-audio', name: 'ZOTL Ultralinear+',
      source: 'https://www.lineartubeaudio.com/products/zotl-ultralinear-amplifier',
      values: {
        'amplifier_type' => 'tube',
        'amplifier_class' => 'class_ab',
        'input_connectors' => %w[rca],
        'speaker_outputs' => %w[binding_posts],
        'dimensions' => { 'unit' => 'in', 'value' => { 'w' => 17.0, 'l' => 13.875, 'h' => 5.0 } }
      }
    },
    {
      id: 1837, brand: 'kinki-studio', name: 'EX-M1+',
      source: 'https://www.kinki-studio.com/product-page/ex-m1',
      values: { 'channel_configuration' => 'stereo' }
    },
    {
      # Passive: the page gives a recommended amplifier power of 20-150 W.
      id: 1838, brand: 'aperion-audio', name: 'Grandis GR6',
      source: 'https://www.aperionaudio.com/products/gr6',
      values: {
        'loudspeaker_amplification_type' => 'passive',
        'loudspeaker_enclosure_type' => 'ported',
        'loudspeaker_bi_amping' => true
      }
    }
  ].freeze

  def up
    definitions = CustomAttribute.all.index_by(&:label)
    written = 0

    SPECIFICATIONS.each do |specification|
      product = matching_product(specification)
      next say("Skipped #{specification[:id]}: no #{specification[:brand]} #{specification[:name]}") if product.nil?

      current = product.custom_attributes || {}
      additions = specification[:values].reject { |label, _| current.key?(label) }
                                        .to_h { |label, value| [label, stored_value(definitions[label], value)] }
                                        .compact
      next if additions.empty?

      product.custom_attributes = current.merge(additions)
      product.comment = "Specifications from #{specification[:source]}"
      if product.save
        written += 1
        say("#{product.id} #{product.name}: #{additions.keys.join(', ')}")
      else
        say("Skipped #{product.id} #{product.name}: #{product.errors.full_messages.to_sentence}")
      end
    end

    say("#{written} product(s) got specifications.")
  end

  # Removes a value only while it is still the one written above. A value changed since then was
  # changed by a person, and stays.
  def down
    definitions = CustomAttribute.all.index_by(&:label)

    SPECIFICATIONS.each do |specification|
      product = matching_product(specification)
      next if product.nil?

      current = product.custom_attributes || {}
      remaining = current.reject do |label, value|
        specification[:values].key?(label) && value == stored_value(definitions[label], specification[:values][label])
      end
      next if remaining == current

      product.custom_attributes = remaining
      product.comment = 'Revert: specifications from brand website'
      product.save
    end
  end

  private

  def matching_product(specification)
    product = Product.includes(:brand).find_by(id: specification[:id])
    return if product.nil?
    return unless product.brand.slug == specification[:brand] && product.name == specification[:name]

    product
  end

  # Option keys become the ids of this environment. nil when the definition or an option key does
  # not exist here, so the label is left out rather than written with a value nothing can read.
  def stored_value(definition, value)
    return if definition.nil?
    return value unless definition.option_input_type? || definition.options_input_type?

    ids = Array(value).map { |key| definition.options&.key(key) }
    return if ids.any?(&:nil?)

    definition.option_input_type? ? ids.first : ids
  end
end
