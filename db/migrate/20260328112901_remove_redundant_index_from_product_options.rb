class RemoveRedundantIndexFromProductOptions < ActiveRecord::Migration[8.1]
  def change
    remove_index :product_options, name: "index_product_options_on_product_id" if index_exists?(:product_options, name: "index_product_options_on_product_id")
  end
end
