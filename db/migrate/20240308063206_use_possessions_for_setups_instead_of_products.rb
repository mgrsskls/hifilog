class UsePossessionsForSetupsInsteadOfProducts < ActiveRecord::Migration[7.1]
  def change
    rename_table :setup_products, :setup_possessions
    add_column :setup_possessions, :possession_id, :bigint
  end
end
