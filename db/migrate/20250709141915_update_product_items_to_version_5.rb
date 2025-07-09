class UpdateProductItemsToVersion5 < ActiveRecord::Migration[8.0]
  def change
    update_view :product_items, version: 5, revert_to_version: 4
  end
end
