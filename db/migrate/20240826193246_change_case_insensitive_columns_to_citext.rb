class ChangeCaseInsensitiveColumnsToCitext < ActiveRecord::Migration[7.1]
  def change
    change_column :custom_products, :name, :citext, null: false
    change_column :sub_categories, :name, :citext, null: false
    change_column :sub_categories, :slug, :citext, null: false
    change_column :setups, :name, :citext, null: false
    change_column :product_variants, :name, :citext, null: false
  end
end
