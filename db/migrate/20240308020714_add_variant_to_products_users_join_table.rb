class AddVariantToProductsUsersJoinTable < ActiveRecord::Migration[7.1]
  def change
    add_column :products_users, :variant_id, :bigint
  end
end
