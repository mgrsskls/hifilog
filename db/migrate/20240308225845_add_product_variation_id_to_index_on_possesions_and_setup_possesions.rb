class AddProductVariationIdToIndexOnPossesionsAndSetupPossesions < ActiveRecord::Migration[7.1]
  def change
    add_index :possessions, [:product_id, :user_id, :product_variant_id], unique: true

    add_index :setup_possessions, [:possession_id, :setup_id], unique: true
  end
end
