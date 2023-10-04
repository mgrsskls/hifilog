class CreateProductsCategoriesAndProductsSubCategoriesJoinTable < ActiveRecord::Migration[7.0]
  def change
    create_join_table :products, :categories
    create_join_table :products, :sub_categories
    remove_column :products, :category_id
    remove_column :products, :sub_category_id
  end
end
