class AddMissingIndicesNo2 < ActiveRecord::Migration[7.1]
  def change
    add_index :setups, :user_id
    add_index :products, :brand_id
  end
end
