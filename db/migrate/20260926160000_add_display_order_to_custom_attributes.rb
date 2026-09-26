# frozen_string_literal: true

# Adds the display group and the display position of a custom attribute. The product page, the
# product form and the filter sort custom attributes by these two values. See
# docs/custom-attributes.md, "Display order".
#
# The columns are NOT NULL. This migration sets values for all custom attributes that exist now,
# so that no attribute is without a place in the order. The values are data, not code, so an admin
# can change them later in ActiveAdmin.
#
# A label that is not in ASSIGNMENTS gets the last group and a high position. Then the NOT NULL
# change cannot fail, and the attribute shows at the end until an admin sets a better value.
class AddDisplayOrderToCustomAttributes < ActiveRecord::Migration[8.1]
  ASSIGNMENTS = {
    'design' => %w[
      amplifier_type
      cartridge_type
      cable_interconnect_type
      headphone_driver_type
      headphone_enclosure_type
      headphone_connection_type
      loudspeaker_enclosure_type
      loudspeaker_driver_configuration
      loudspeaker_driver_types
      loudspeaker_amplification_type
      turntable_drive_type
      turntable_operation_type
      channel_configuration
      supported_cartridge_types
      assembly
    ],
    'performance' => %w[
      amplifier_output_power
      headphone_amplifier_output_power
      loudspeaker_rms_power
      loudspeaker_peak_power
      loudspeaker_recommended_amplifier_power
      loudspeaker_sensitivity
      headphone_sensitivity
      loudspeaker_peak_spl
      nominal_impedance
      loudspeaker_minimum_impedance
      frequency_response_range
    ],
    'connectivity' => %w[
      input_connectors
      output_connectors
      speaker_outputs
      headphone_outputs
      loudspeaker_bi_wiring
      loudspeaker_bi_amping
    ],
    'physical' => %w[
      dimensions
      weight
    ]
  }.freeze

  FALLBACK_GROUP = 'physical'
  FALLBACK_POSITION = 1000

  def up
    add_column :custom_attributes, :display_group, :string
    add_column :custom_attributes, :display_position, :integer

    ASSIGNMENTS.each do |group, labels|
      labels.each_with_index do |label, index|
        execute <<~SQL.squish
          UPDATE custom_attributes
          SET display_group = #{connection.quote(group)}, display_position = #{(index + 1) * 10}
          WHERE label = #{connection.quote(label)}
        SQL
      end
    end

    execute <<~SQL.squish
      UPDATE custom_attributes
      SET display_group = #{connection.quote(FALLBACK_GROUP)}, display_position = #{FALLBACK_POSITION}
      WHERE display_group IS NULL
    SQL

    change_column_null :custom_attributes, :display_group, false
    change_column_null :custom_attributes, :display_position, false
  end

  def down
    remove_column :custom_attributes, :display_position
    remove_column :custom_attributes, :display_group
  end
end
