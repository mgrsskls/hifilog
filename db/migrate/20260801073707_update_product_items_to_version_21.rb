# frozen_string_literal: true

class UpdateProductItemsToVersion21 < ActiveRecord::Migration[8.1]
  def change
    update_view :product_items, version: 21, revert_to_version: 20
  end
end
