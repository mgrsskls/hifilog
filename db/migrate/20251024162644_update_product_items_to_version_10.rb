class UpdateProductItemsToVersion10 < ActiveRecord::Migration[8.0]
  def change
    update_view :product_items, version: 10, revert_to_version: 9
  end
end
