class AddCascadeDeleteToPossessions < ActiveRecord::Migration[8.1]
  def change
    # Remove the old foreign key first
    remove_foreign_key :possessions, :product_options

    # Add it back with the cascade rule
    add_foreign_key :possessions, :product_options, on_delete: :cascade
  end
end
