class DropDeprecatedColumnsFromSetupPossessions < ActiveRecord::Migration[7.1]
  def change
    remove_column :setup_possessions, :product_id
    remove_column :setup_possessions, :product_variant_id
  end
end
