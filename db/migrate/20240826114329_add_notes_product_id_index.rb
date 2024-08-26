class AddNotesProductIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :notes, :product_id, name: :index_notes_product_id
  end
end
