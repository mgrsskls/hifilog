# frozen_string_literal: true

class UpdateContributeProductItemsToVersion4 < ActiveRecord::Migration[8.1]
  def change
    update_view :contribute_product_items, version: 4, revert_to_version: 3
  end
end
