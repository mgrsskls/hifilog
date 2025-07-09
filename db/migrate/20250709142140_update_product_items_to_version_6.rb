class UpdateProductItemsToVersion6 < ActiveRecord::Migration[8.0]
  def change
    update_view :product_items, version: 6, revert_to_version: 5
  end
end
