class AddPrevOwnedTable < ActiveRecord::Migration[7.1]
  def change
    create_table :prev_owned do |t|
      t.bigint "user_id", null: false
      t.bigint "product_id", null: false
      t.index ["product_id", "user_id"], name: "index_prev_owned_on_product_id_and_user_id", unique: true
      t.index ["product_id"], name: "index_prev_owned_on_product_id"
      t.index ["user_id"], name: "index_prev_owned_on_user_id"
    end
  end
end
