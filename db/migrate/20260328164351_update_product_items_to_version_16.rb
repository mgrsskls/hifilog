class UpdateProductItemsToVersion16 < ActiveRecord::Migration[8.1]
  def change
    update_view :product_items, version: 16, revert_to_version: 15
  end
end
