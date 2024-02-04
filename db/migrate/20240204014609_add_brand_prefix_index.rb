class AddBrandPrefixIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :brands, "left(lower(name),1)", name: "index_brands_name_prefix"
  end
end
