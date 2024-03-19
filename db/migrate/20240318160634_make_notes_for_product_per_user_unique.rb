class MakeNotesForProductPerUserUnique < ActiveRecord::Migration[7.1]
  def change
    add_index :notes, [:user_id, :product_id, :product_variant_id]
  end
end
