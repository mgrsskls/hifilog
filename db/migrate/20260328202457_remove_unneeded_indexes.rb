class RemoveUnneededIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :brands, name: "index_brands_on_name_trgm", column: :name
    remove_index :brands_sub_categories, name: "index_brands_sub_categories_on_brand_id", column: :brand_id
    remove_index :brands_sub_categories, name: "index_brands_sub_categories_on_sub_category_id", column: :sub_category_id
    remove_index :custom_attributes_sub_categories, name: "index_custom_attributes_sub_categories_on_sub_category_id", column: :sub_category_id
    remove_index :friendly_id_slugs, name: "index_friendly_id_slugs_on_slug_and_sluggable_type", column: [:slug, :sluggable_type]
    remove_index :products, name: "index_products_on_name_trgm", column: :name
    remove_index :products_sub_categories, name: "index_products_sub_categories_on_product_id", column: :product_id
  end
end
