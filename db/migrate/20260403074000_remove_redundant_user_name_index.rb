# frozen_string_literal: true

class RemoveRedundantUserNameIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, name: "index_users_user_name" if index_exists?(:users, name: "index_users_user_name")
  end
end

