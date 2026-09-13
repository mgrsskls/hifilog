# frozen_string_literal: true

class CreateBrandFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :brand_follows do |t|
      # Both single-column indexes the references would add are covered by the composite
      # indexes below, in the order the two read paths need them.
      t.references :user, null: false, foreign_key: true, index: false
      t.references :brand, null: false, foreign_key: true, index: false

      t.timestamps
    end

    # One follow per user and brand; also the lookup for "which brands does this user follow".
    add_index :brand_follows, [:user_id, :brand_id], unique: true
    # Follower lists and the feed cutoff read by brand, newest first.
    add_index :brand_follows, [:brand_id, :created_at]
  end
end
