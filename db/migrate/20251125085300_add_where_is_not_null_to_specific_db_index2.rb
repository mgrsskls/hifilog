class AddWhereIsNotNullToSpecificDbIndex2 < ActiveRecord::Migration[8.1]
  def change
    remove_index :products, name: "index_products_on_model_no_and_brand_id"

    add_index :products, [:model_no, :brand_id], where: "model_no IS NOT NULL", name: :index_products_on_model_no_and_brand_id, unique: true
  end
end
