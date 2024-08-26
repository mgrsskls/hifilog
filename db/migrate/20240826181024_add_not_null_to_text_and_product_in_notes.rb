class AddNotNullToTextAndProductInNotes < ActiveRecord::Migration[7.1]
  def change
    change_column :notes, :text, :text, null: false
    change_column :notes, :product_id, :bigint, null: false
  end
end
