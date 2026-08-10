# frozen_string_literal: true

class UpdateProductItemsToVersion22 < ActiveRecord::Migration[8.1]
  def change
    update_view :product_items, version: 22, revert_to_version: 21
  end
end
