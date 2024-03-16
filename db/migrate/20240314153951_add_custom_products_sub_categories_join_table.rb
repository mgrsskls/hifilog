class AddCustomProductsSubCategoriesJoinTable < ActiveRecord::Migration[7.1]
  def change
    create_join_table :custom_products, :sub_categories
  end
end
