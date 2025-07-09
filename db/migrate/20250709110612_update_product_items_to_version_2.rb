class UpdateProductItemsToVersion2 < ActiveRecord::Migration[8.0]
  def change
    update_view :product_items, version: 2, revert_to_version: 1
  end
end
