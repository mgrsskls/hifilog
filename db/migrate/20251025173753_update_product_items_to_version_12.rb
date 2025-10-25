class UpdateProductItemsToVersion12 < ActiveRecord::Migration[8.0]
  def change
    update_view :product_items, version: 12, revert_to_version: 11
  end
end
