# frozen_string_literal: true

# Fills more empty specifications of existing products from the brand websites that the brand
# importer crawled (docs/import.md). AddScrapedSpecificationsToProducts took the products whose
# import candidate had extracted figures. This one takes the other products that an import
# candidate matched by brand and name, and reads the figures from the candidate's page.
#
# Many of these figures are not in the crawled copy of the page: the crawl often holds only the
# shop description, without the specification table. Each figure that the crawl does not contain
# was checked on the live brand website on 2026-09-27. Figures that could be confirmed in neither
# place are not written. The Fezz Audio website refused the check, so of its products only the
# amplifier class, which the crawl states, is written.
#
# The rules of AddScrapedSpecificationsToProducts apply: no prices, no condition that the page does
# not state, no tube amplifier power that the page gives once for its 4 and 8 ohm taps, no shipping
# weights, and no figure that disagrees with the product. In addition, these were left out:
#
#   * Dimensions that the page gives without the order of the axes ("420x380x220 mm").
#   * A connector list that the page gives only in part ("four digital inputs"). An incomplete
#     list reads as a complete one.
#   * Headphone amplifier power that the page gives per output (balanced and single-ended) or at a
#     load other than 32 or 300 ohm.
#   * A figure that the page states twice with different values (Castle Richmond IV: 87 and 88 dB).
#   * A figure for a product that comes in versions the page gives separately (Scheu tonearms in
#     9 and 12 inch) or as a range (effective mass "14-16gr.").
#   * The driver type of an in-ear monitor with electrostatic drivers besides dynamic and balanced
#     armature ones (ThieAudio Prestige LTD). The hybrid option names dynamic and balanced armature
#     drivers only.
#
# Pages that stated nothing new: Pro-Ject (the pages are gone), iBasso (no specifications in the
# page), Qudelix T71 (the page is for the T71 IEM, not the DAC), and the Analog Ethos shop pages
# of the Legendarium, Requiem, Exordium and AE1.
#
# The mechanics are those of AddScrapedSpecificationsToProducts: a label that already has a value
# is never touched, a product whose brand or name differs is skipped, option keys are resolved to
# ids at run time, and the product is saved through the model so that the changelog shows the source.
class AddMoreScrapedSpecificationsToProducts < ActiveRecord::Migration[8.1]
  SPECIFICATIONS = [
    {
      # "Gniazdo słuchawkowe 6.3mm oraz XLR". The page does not say that the XLR socket has 4 pins.
      id: 50, brand: 'feliks-audio', name: 'Envy',
      source: 'https://feliksaudio.pl/product/envy/',
      values: {
        'input_connectors' => %w[rca xlr],
        'headphone_outputs' => %w[jack_6_35mm],
        'amplifier_class' => 'class_a',
        'weight' => { 'unit' => 'kg', 'value' => 15.1 },
        # "35x33x18,5cm (LxWxH) – bez lamp", without the tubes.
        'dimensions' => { 'unit' => 'cm', 'value' => { 'w' => 33.0, 'l' => 35.0, 'h' => 18.5 } }
      }
    },
    {
      id: 58, brand: 'wharfedale', name: 'Dovedale',
      source: 'https://www.wharfedale.co.uk/products/dovedale',
      values: {
        'woofer_size' => { 'unit' => 'cm', 'value' => 25.0, 'second' => { 'unit' => 'in', 'value' => 10.0 } }
      }
    },
    {
      id: 104, brand: 'kef', name: 'LS50 Meta',
      source: 'https://kef.com/products/ls50-meta',
      values: {
        'loudspeaker_enclosure_type' => 'ported',
        'loudspeaker_driver_configuration' => '2_way',
        'loudspeaker_recommended_amplifier_power' => { 'value' => { 'min' => 40.0, 'max' => 100.0 } },
        'loudspeaker_sensitivity' => { 'unit' => 'db', 'value' => 85.0, 'qualifier' => 'drive_283v_1m' },
        'loudspeaker_peak_spl' => { 'value' => 106.0, 'qualifier' => 'distance_1m' },
        'nominal_impedance' => { 'value' => 8.0 },
        'loudspeaker_minimum_impedance' => { 'value' => 3.5 },
        'frequency_response_range' => {
          'value' => { 'min' => 79.0, 'max' => 28_000.0 }, 'qualifier' => 'plus_minus_3_db'
        },
        'dimensions' => {
          'unit' => 'cm', 'value' => { 'w' => 20.0, 'l' => 28.05, 'h' => 30.2 },
          'second' => { 'unit' => 'in', 'value' => { 'w' => 7.9, 'l' => 11.0, 'h' => 11.9 } }
        },
        'weight' => { 'unit' => 'kg', 'value' => 7.8, 'second' => { 'unit' => 'lb', 'value' => 17.2 } },
        'woofer_size' => { 'unit' => 'cm', 'value' => 13.0, 'second' => { 'unit' => 'in', 'value' => 5.25 } }
      }
    },
    {
      # No weight: "20.1kg (44.3lbs)" does not say whether it is one speaker or the pair.
      id: 105, brand: 'kef', name: 'LS50 Wireless II',
      source: 'https://kef.com/products/ls50-wireless-2',
      values: {
        'frequency_response_range' => {
          'value' => { 'min' => 45.0, 'max' => 28_000.0 }, 'qualifier' => 'plus_minus_3_db'
        },
        'loudspeaker_peak_spl' => { 'value' => 108.0, 'qualifier' => 'distance_1m' },
        'dimensions' => {
          'unit' => 'cm', 'value' => { 'w' => 20.0, 'l' => 31.1, 'h' => 30.5 },
          'second' => { 'unit' => 'in', 'value' => { 'w' => 7.9, 'l' => 12.2, 'h' => 12.0 } }
        },
        'woofer_size' => { 'unit' => 'cm', 'value' => 13.0 }
      }
    },
    {
      # No stylus shape: "Nude Fine Line" is not one of the options by name. The frequency response
      # is "+2 / -0 dB", which is not a qualifier.
      id: 112, brand: 'ortofon', name: '2M Bronze',
      source: 'https://www.ortofon.com/products/2m-bronze',
      values: {
        'weight' => { 'unit' => 'g', 'value' => 7.2 },
        'frequency_response_range' => { 'value' => { 'min' => 20.0, 'max' => 20_000.0 } },
        'cartridge_output_voltage' => { 'unit' => 'mv', 'value' => 5.0, 'qualifier' => 'velocity_5_cms' },
        'cartridge_compliance' => { 'unit' => 'um_mn', 'value' => 22.0 },
        'tracking_force' => { 'unit' => 'g', 'value' => { 'min' => 1.4, 'max' => 1.7 } }
      }
    },
    {
      id: 113, brand: 'ortofon', name: '2M Black LVB 250',
      source: 'https://www.ortofon.com/products/2m-black-lvb-250',
      values: {
        'weight' => { 'unit' => 'g', 'value' => 7.2 },
        'frequency_response_range' => { 'value' => { 'min' => 20.0, 'max' => 20_000.0 } },
        'stylus_shape' => 'shibata',
        'cartridge_output_voltage' => { 'unit' => 'mv', 'value' => 5.0, 'qualifier' => 'velocity_5_cms' },
        'cartridge_compliance' => { 'unit' => 'um_mn', 'value' => 22.0 },
        'tracking_force' => { 'unit' => 'g', 'value' => { 'min' => 1.5, 'max' => 1.7 } }
      }
    },
    {
      # "Niespotykana konstrukcja PSE pracująca w klasie A".
      id: 121, brand: 'fezz-audio', name: 'Lybra 300B',
      source: 'https://fezzaudio.com/produkt/fezz-lybra-300b-evolution/',
      values: { 'amplifier_class' => 'class_a' }
    },
    {
      # "3,5-Millimeter-Klinkenbuchse sowie ein symmetrischer 4,4-Millimeter-Pentaconn-Anschluss",
      # "DSD-Streams bis zu DSD256".
      id: 147, brand: 'cayin', name: 'RU7',
      source: 'https://cayin.com/produkt/cayin-ru7-usb-dac-dongle/',
      values: {
        'input_connectors' => %w[usb_c],
        'headphone_outputs' => %w[jack_3_5mm jack_4_4mm],
        'dsd_support' => true
      }
    },
    {
      id: 163, brand: 'analog-ethos', name: 'AE1-C',
      source: 'https://www.analogethos.com/product-page/ae1-c-stereo-tube-amplifier-kit',
      values: { 'speaker_outputs' => %w[binding_posts] }
    },
    {
      id: 490, brand: 'leak', name: 'Stereo 130',
      source: 'https://www.leakaudio.com/products/stereo-130-integrated-amplifier-in-silver',
      values: {
        'channel_configuration' => 'stereo',
        'input_connectors' => %w[rca usb_b spdif_coaxial toslink bluetooth],
        'amplifier_output_power' => { 'unit' => 'w', 'value' => { 'ohm_8' => 45.0, 'ohm_4' => 65.0 } },
        'dimensions' => { 'unit' => 'in', 'value' => { 'w' => 11.88, 'l' => 10.62, 'h' => 4.64 } },
        'weight' => { 'unit' => 'lb', 'value' => 15.27 }
      }
    },
    {
      # "Experience the ... ultra light weight open-air design".
      id: 584, brand: 'koss', name: 'KSC75',
      source: 'https://www.koss.com/products/ksc75',
      values: {
        'headphone_enclosure_type' => 'open_back',
        'nominal_impedance' => { 'value' => 60.0 },
        'frequency_response_range' => { 'value' => { 'min' => 15.0, 'max' => 25_000.0 } },
        'headphone_sensitivity' => { 'unit' => 'db', 'value' => 101.0, 'qualifier' => 'drive_1mw' }
      }
    },
    {
      id: 585, brand: 'koss', name: 'Porta Pro',
      source: 'https://www.koss.com/products/porta-pro',
      values: {
        'nominal_impedance' => { 'value' => 60.0 },
        'frequency_response_range' => { 'value' => { 'min' => 15.0, 'max' => 25_000.0 } },
        'headphone_sensitivity' => { 'unit' => 'db', 'value' => 101.0, 'qualifier' => 'drive_1mw' }
      }
    },
    {
      id: 591, brand: 'buchardt-audio', name: 'Anniversary 10',
      source: 'https://buchardtaudio.com/products/anniversary-10',
      values: { 'woofer_size' => { 'unit' => 'in', 'value' => 6.5 } }
    },
    {
      # The kit page: "The standard model includes: ... speaker binding posts".
      id: 599, brand: 'analog-ethos', name: 'Pacific 63',
      source: 'https://www.analogethos.com/product-page/pacific-63-kit',
      values: { 'speaker_outputs' => %w[binding_posts] }
    },
    {
      # "3.5mm S-Balanced or 4.4mm Balanced headphone outputs", "INPUT: USB-C", "Native DSD256".
      # "NET WEIGHT 65.5g", in kilograms because DACs and headphone amplifiers offer no grams.
      id: 604, brand: 'ifi', name: 'Go bar Kensei',
      source: 'https://ifi-audio.com/products/go-bar-kensei',
      values: {
        'input_connectors' => %w[usb_c],
        'headphone_outputs' => %w[jack_3_5mm jack_4_4mm],
        'dsd_support' => true,
        'weight' => { 'unit' => 'kg', 'value' => 0.0655 }
      }
    },
    {
      id: 647, brand: 'wharfedale', name: 'Super Linton',
      source: 'https://www.wharfedale.co.uk/products/super-linton',
      values: {
        'woofer_size' => { 'unit' => 'cm', 'value' => 20.0, 'second' => { 'unit' => 'in', 'value' => 8.0 } }
      }
    },
    {
      id: 1353, brand: 'fosi-audio', name: 'V3',
      source: 'https://fosiaudio.com/products/fosi-audio-v3-300w-x2-2-0-channel-hi-fi-stereo-audio-amplifier-with-tpa3255-chip',
      values: {
        'input_connectors' => %w[rca],
        'amplifier_class' => 'class_d',
        'amplifier_output_power' => { 'unit' => 'w', 'value' => { 'ohm_4' => 300.0 } }
      }
    },
    {
      # Passive: the page gives a recommended amplifier power of 25-100 W.
      id: 1472, brand: 'castle', name: 'Richmond IV',
      source: 'https://castle-hifi.co.uk/products/richmond-iv',
      values: {
        'loudspeaker_amplification_type' => 'passive',
        'loudspeaker_recommended_amplifier_power' => { 'value' => { 'min' => 25.0, 'max' => 100.0 } },
        'woofer_size' => { 'unit' => 'cm', 'value' => 15.0 }
      }
    },
    {
      # No inputs: the page gives "four digital inputs" without their types.
      # "Rated Max. Power Output 2 X 50W (8Ω, THD<1%) 2 X 75W (4Ω, THD<1%)".
      id: 1473, brand: 'audiolab', name: '6000A',
      source: 'https://www.audiolab.co.uk/products/6000a',
      values: {
        'amplifier_output_power' => {
          'unit' => 'w', 'value' => { 'ohm_8' => 50.0, 'ohm_4' => 75.0 }, 'qualifier' => 'thd_1_percent'
        },
        'amplifier_class' => 'class_ab',
        'speaker_outputs' => %w[binding_posts]
      }
    },
    {
      id: 1505, brand: 'rel', name: 'Tzero MKIII',
      source: 'https://rel.net/products/tzero-mkiii',
      values: { 'woofer_size' => { 'unit' => 'in', 'value' => 6.5 } }
    },
    {
      id: 1506, brand: 'rel', name: 'T/5x',
      source: 'https://rel.net/products/t-5x',
      values: { 'woofer_size' => { 'unit' => 'in', 'value' => 8.0 } }
    },
    {
      id: 1507, brand: 'svs', name: 'SB-1000 Pro',
      source: 'https://www.svsound.com/products/sb-1000-pro-subwoofer',
      values: { 'woofer_size' => { 'unit' => 'in', 'value' => 12.0 } }
    },
    {
      # "Quad Drive Hybrid UIEM".
      id: 1673, brand: '64-audio', name: 'U4s',
      source: 'https://www.64audio.com/products/u4s',
      values: { 'headphone_driver_type' => 'hybrid_driver' }
    },
    {
      # "1 tia High Driver – 1 High-Mid Driver – 6 Mid Drivers – 1 Dynamic Low Driver".
      id: 1676, brand: '64-audio', name: 'Nio',
      source: 'https://www.64audio.com/products/nio',
      values: { 'headphone_driver_type' => 'hybrid_driver' }
    },
    {
      # "1 tia High Driver – 1 Dynamic Low Driver".
      id: 1677, brand: '64-audio', name: 'Duo',
      source: 'https://www.64audio.com/products/duo',
      values: { 'headphone_driver_type' => 'hybrid_driver' }
    },
    {
      # "Luna Mini to wzmacniacz zintegrowany Class-A".
      id: 1679, brand: 'fezz-audio', name: 'Luna Mini',
      source: 'https://fezzaudio.com/produkt/fezz-luna-mini/',
      values: { 'amplifier_class' => 'class_a' }
    },
    {
      # "Pure-Class-A-Single-Ended-Trioden-Konzept".
      id: 1769, brand: 'cayin', name: 'HA-300MK3',
      source: 'https://cayin.com/produkt/cayin-ha-300mk3-high-end-roehren-kopfhoererverstaerker/',
      values: { 'amplifier_class' => 'class_a' }
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
