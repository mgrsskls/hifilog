class AddIndexesForBrandAndProductFilters < ActiveRecord::Migration[7.0]
  def change
    # Brands
    add_index :brands, :country_code
    add_index :brands, :discontinued

    # Products
    add_index :products, :name
    add_index :products, :discontinued
    add_index :products, :diy_kit
    add_index :products, :release_year
    add_index :products, :release_month
    add_index :products, :release_day

    # Join tables
    add_index :products_sub_categories, :product_id
    add_index :products_sub_categories, :sub_category_id
    add_index :brands_sub_categories, :brand_id
    add_index :brands_sub_categories, :sub_category_id
    add_index :custom_attributes_sub_categories, :custom_attribute_id
    add_index :custom_attributes_sub_categories, :sub_category_id
  end
end
