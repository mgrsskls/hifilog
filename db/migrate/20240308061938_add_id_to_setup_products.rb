class AddIdToSetupProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :setup_products, :id, :primary_key
  end
end
