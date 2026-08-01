# frozen_string_literal: true

class UpdateContributeProductItemsToVersion2 < ActiveRecord::Migration[8.1]
  def change
    update_view :contribute_product_items, version: 2, revert_to_version: 1
  end
end
