# frozen_string_literal: true

class UpdateProductItemsToVersion20 < ActiveRecord::Migration[8.1]
  def change
    update_view :product_items, version: 20, revert_to_version: 19
  end
end
