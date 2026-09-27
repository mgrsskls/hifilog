# frozen_string_literal: true

# Each sub category of an attribute with units now needs its own units: the admin form has no
# default. This migration gives each existing link the units of its attribute, so that nothing
# changes for contributors. An admin then changes the links that need other units, for example
# grams for the weight of a cartridge. See docs/custom-attributes.md, "Units per sub category".
#
# Configuration, not product data: it writes one row for each link between an attribute and a
# sub category.
class FillUnitsOfCustomAttributesSubCategories < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE custom_attributes_sub_categories AS links
      SET units = custom_attributes.units
      FROM custom_attributes
      WHERE custom_attributes.id = links.custom_attribute_id
        AND cardinality(custom_attributes.units) > 0
        AND cardinality(links.units) = 0
    SQL

    # The cache holds the units per sub category as plain data, and it stays through a deploy.
    Rails.cache.delete('custom_attribute_sub_category_units')
  end

  def down
    # The links keep their units. The column itself goes with the previous migration.
  end
end
