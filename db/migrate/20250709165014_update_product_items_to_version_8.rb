class UpdateProductItemsToVersion8 < ActiveRecord::Migration[8.0]
  def change
    update_view :product_items, version: 8, revert_to_version: 7
  end
end
