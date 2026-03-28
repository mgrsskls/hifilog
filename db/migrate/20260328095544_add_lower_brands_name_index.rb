class AddLowerBrandsNameIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :brands, "lower(name)", name: "index_brands_on_lower_name"
  end
end
