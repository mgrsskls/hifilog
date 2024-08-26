class AddNotesProductVariantIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :notes, :product_variant_id, name: :index_notes_product_variant_id
  end
end
