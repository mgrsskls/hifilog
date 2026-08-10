# frozen_string_literal: true

# `full_name` has done its job: BackfillBrandNamesFromFullName (20260809120100) classified
# every value it could into `abbreviation` / `legal_name`. Whatever it could not classify was
# printed by that migration's own output; nothing left in the column is otherwise recoverable.
class RemoveFullNameFromBrands < ActiveRecord::Migration[8.1]
  def up
    remove_index :brands, :full_name, name: 'index_brands_on_full_name_trgm'
    remove_column :brands, :full_name
  end

  def down
    add_column :brands, :full_name, :string
    add_index :brands, :full_name, using: :gin, opclass: :gin_trgm_ops,
                                   name: 'index_brands_on_full_name_trgm'
  end
end
