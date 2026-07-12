# frozen_string_literal: true

class CreateUserFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :user_follows do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }
      t.references :followed, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :user_follows, %i[follower_id followed_id], unique: true
  end
end
