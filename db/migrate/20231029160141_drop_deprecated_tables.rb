class DropDeprecatedTables < ActiveRecord::Migration[7.0]
  def change
    drop_table :tags
    drop_table :rooms_users
  end
end
