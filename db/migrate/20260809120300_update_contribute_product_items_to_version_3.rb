# frozen_string_literal: true

class UpdateContributeProductItemsToVersion3 < ActiveRecord::Migration[8.1]
  def change
    update_view :contribute_product_items, version: 3, revert_to_version: 2
  end
end
