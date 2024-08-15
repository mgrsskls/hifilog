class AddCustomProductIdToPrevOwneds < ActiveRecord::Migration[7.1]
  def change
    add_column :prev_owneds, :custom_product_id, :bigint
  end
end
