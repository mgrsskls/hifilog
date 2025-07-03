class RemoveIndicesFromProductVariants < ActiveRecord::Migration[8.0]
  def change
    remove_index :product_variants, name: "index_product_variants_on_model_no"
    remove_index :product_variants, name: "index_product_variants_on_product_id_and_name_and_release_year"
  end
end
