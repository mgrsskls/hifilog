# frozen_string_literal: true

class CreateContributeProductItems < ActiveRecord::Migration[8.1]
  def change
    create_view :contribute_product_items
  end
end
