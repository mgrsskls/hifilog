class UniqueIndexOnNotes < ActiveRecord::Migration[7.1]
  def change
    remove_index :notes, name: "index_notes_on_user_id_and_product_id_and_product_variant_id"
    add_index :notes, [:user_id, :product_id, :product_variant_id], unique: true
  end
end
