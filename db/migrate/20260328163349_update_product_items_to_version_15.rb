class UpdateProductItemsToVersion15 < ActiveRecord::Migration[8.1]
  def change
    update_view :product_items, version: 15, revert_to_version: 14
  end
end
