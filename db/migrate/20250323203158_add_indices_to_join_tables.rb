class AddIndicesToJoinTables < ActiveRecord::Migration[8.0]
  def change
    add_index :custom_attributes_sub_categories, [:sub_category_id, :custom_attribute_id], unique: true
    add_index :products_sub_categories, [:product_id, :sub_category_id], unique: true
    add_index :custom_products_sub_categories, [:custom_product_id, :sub_category_id], unique: true
    add_index :app_news_users, [:app_news_id, :user_id], unique: true
  end
end
