class AddPossessionsProductVariantIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :possessions, :product_variant_id, name: :index_possessions_product_variant_id
  end
end
