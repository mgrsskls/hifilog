class RemoveUnneededUserBlockAndFollowIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :user_blocks, name: "index_user_blocks_on_blocker_id", column: :blocker_id
    remove_index :user_follows, name: "index_user_follows_on_follower_id", column: :follower_id
  end
end
