class UpdateProductItemsToVersion11 < ActiveRecord::Migration[8.0]
  def change
    update_view :product_items, version: 11, revert_to_version: 10
  end
end
