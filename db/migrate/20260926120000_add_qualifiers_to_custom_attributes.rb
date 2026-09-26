# frozen_string_literal: true

# The measurement condition a number was quoted under: ±3 dB for a frequency response, 1% THD for
# an output power. A third axis beside `units` and `inputs`.
#
# No `null: false`, on purpose. `units` and `inputs` do not have it, and the constraint would make
# the null-constraint checker of database_consistency ask for a presence validation -- which on an
# array that defaults to [] rejects every definition that declares no qualifier, because
# `[].present?` is false.
#
# No backfill: an absent condition is the honest value for every row that exists.
# See docs/custom-attribute-qualifiers.md.
class AddQualifiersToCustomAttributes < ActiveRecord::Migration[8.1]
  def change
    add_column :custom_attributes, :qualifiers, :string, array: true, default: []
  end
end
