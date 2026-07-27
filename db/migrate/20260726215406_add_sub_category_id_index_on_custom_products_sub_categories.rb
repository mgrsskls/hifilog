class AddSubCategoryIdIndexOnCustomProductsSubCategories < ActiveRecord::Migration[8.1]
  def change
    add_index :custom_products_sub_categories, :sub_category_id
  end
end
