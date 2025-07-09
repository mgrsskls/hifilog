class UpdateProductItemsToVersion7 < ActiveRecord::Migration[8.0]
  def change
    update_view :product_items, version: 7, revert_to_version: 6
  end
end
