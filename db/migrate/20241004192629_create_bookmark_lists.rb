class CreateBookmarkLists < ActiveRecord::Migration[7.2]
  def change
    create_table :bookmark_lists do |t|
      t.string :name, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
  end
end
