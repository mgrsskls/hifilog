# frozen_string_literal: true

class UpdateProductItemsToVersion18 < ActiveRecord::Migration[8.1]
  def change
    update_view :product_items, version: 18, revert_to_version: 17
  end
end
