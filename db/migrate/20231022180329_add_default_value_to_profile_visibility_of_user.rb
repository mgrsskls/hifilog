class AddDefaultValueToProfileVisibilityOfUser < ActiveRecord::Migration[7.0]
  def change
    change_column :users, :profile_visibility, :integer, default: 0
  end
end
