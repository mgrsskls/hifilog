class ApplyDatabaseImprovements < ActiveRecord::Migration[8.1]
  def change
    add_index :product_options, [:model_no, :product_id], unique: true, if_not_exists: true
    add_index :product_options, [:model_no, :product_variant_id], unique: true, if_not_exists: true
    add_index :products, [:model_no, :brand_id], unique: true, if_not_exists: true

    add_foreign_key :bookmarks, :bookmark_lists, if_not_exists: true
  end
end
