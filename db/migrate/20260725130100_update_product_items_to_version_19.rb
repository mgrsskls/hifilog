# frozen_string_literal: true

class UpdateProductItemsToVersion19 < ActiveRecord::Migration[8.1]
  def change
    update_view :product_items, version: 19, revert_to_version: 18
  end
end
