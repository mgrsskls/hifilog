class AddNullifyOnDeleteToNotes < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :notes, column: :product_variant_id
    add_foreign_key :notes, :product_variants, column: :product_variant_id, on_delete: :nullify

    remove_foreign_key :notes, column: :product_id
    add_foreign_key :notes, :products, column: :product_id, on_delete: :nullify

    remove_foreign_key :notes, column: :user_id
    add_foreign_key :notes, :users, column: :user_id, on_delete: :nullify
  end
end