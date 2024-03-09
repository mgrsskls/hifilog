class AllowNullValuesForProductIdAndProductVariantIdInSetupPossessions < ActiveRecord::Migration[7.1]
  def change
    change_column :setup_possessions, :product_id, :bigint, null: true
  end
end
