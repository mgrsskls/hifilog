class RemoveRedundantIndexOnUserIdAndProductVariantIdOnNotes < ActiveRecord::Migration[7.1]
  def change
    remove_index :notes, name: 'index_notes_on_user_id_and_product_variant_id'
  end
end
