# frozen_string_literal: true

# Lets an attribute offer different options in different categories.
#
# `options` belongs to the attribute, but which of them apply does not: `input_connectors` is
# one question everywhere, while a phono stage answers it with RCA and XLR and a DAC answers it
# with USB, coaxial and TOSLINK. Until now the whole list was offered everywhere, so a phono
# stage's form asked about I2S.
#
# Applicability already travels along the attribute-to-subcategory join, which is where the
# subset belongs too. An empty array means "all of them", so every existing row keeps its
# current behaviour and no backfill is needed.
#
# The join table was created for `has_and_belongs_to_many` and therefore has no primary key. A
# join *model* needs one, so this adds it. The existing HABTM associations keep working
# untouched -- the model is additive, for the rows' own data.
#
# The five product_items / contribute_product_items views join this table but select named
# columns, so none of them need a new version.
class AddOptionScopeToCustomAttributesSubCategories < ActiveRecord::Migration[8.1]
  def up
    # Option ids, matching the keys of custom_attributes.options -- which are strings, and are
    # what products store. Empty is the default and means the subset is unset.
    add_column :custom_attributes_sub_categories, :option_ids, :text, array: true, default: [], null: false

    add_column :custom_attributes_sub_categories, :id, :primary_key
  end

  def down
    remove_column :custom_attributes_sub_categories, :id
    remove_column :custom_attributes_sub_categories, :option_ids
  end
end
