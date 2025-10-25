class UpdateProductItemsToVersion13 < ActiveRecord::Migration[8.0]
  def change
    update_view :product_items, version: 13, revert_to_version: 12
  end
end
