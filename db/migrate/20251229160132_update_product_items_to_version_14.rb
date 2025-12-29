class UpdateProductItemsToVersion14 < ActiveRecord::Migration[8.1]
  def change
    update_view :product_items, version: 14, revert_to_version: 13
  end
end
