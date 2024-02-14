class AddIndexToBrandsSubCategoriesJoinTable < ActiveRecord::Migration[7.1]
  def change
    add_index :brands_sub_categories, [:brand_id, :sub_category_id], unique: true
  end
end
