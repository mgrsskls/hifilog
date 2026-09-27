# frozen_string_literal: true

# Lets a sub category offer other units for a custom attribute than the definition does, for
# example grams for the weight of a cartridge. An empty array means "the units of the definition".
# See docs/custom-attributes.md, "Units per sub category".
class AddUnitsToCustomAttributesSubCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :custom_attributes_sub_categories, :units, :string, array: true, default: [], null: false
  end
end
