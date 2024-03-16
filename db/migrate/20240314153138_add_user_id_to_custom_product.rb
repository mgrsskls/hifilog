class AddUserIdToCustomProduct < ActiveRecord::Migration[7.1]
  def change
    add_column :custom_products, :user_id, :bigint, null: false
    change_column_null :custom_products, :name, false
  end
end
