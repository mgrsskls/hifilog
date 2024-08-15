class AllowProductIdInPrevOwnedsToBeNull < ActiveRecord::Migration[7.1]
  def change
    change_column :prev_owneds, :product_id, :bigint, null: true
  end
end
