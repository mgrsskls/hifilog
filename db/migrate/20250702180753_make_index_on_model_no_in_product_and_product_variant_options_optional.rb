class MakeIndexOnModelNoInProductAndProductVariantOptionsOptional < ActiveRecord::Migration[8.0]
  def change
    remove_index :product_options, name: "index_product_options_on_model_no_and_product_id"
    remove_index :product_options, name: "index_product_options_on_model_no_and_product_variant_id"
    add_index :product_options, [:model_no, :product_id], unique: true, where: "model_no IS NOT NULL"
    add_index :product_options, [:model_no, :product_variant_id], unique: true, where: "model_no IS NOT NULL"
  end
end
