# frozen_string_literal: true

class AddProductOptionsProductIdIndexForProductItemAssociation < ActiveRecord::Migration[8.1]
  def change
    # Used by ProductItem.has_many :product_options (foreign key: product_options.product_id).
    # Some index checks require a direct index on product_id even if composite indexes exist.
    add_index :product_options,
              :product_id,
              name: "index_product_options_on_product_id" unless index_exists?(:product_options, name: "index_product_options_on_product_id")
  end
end

