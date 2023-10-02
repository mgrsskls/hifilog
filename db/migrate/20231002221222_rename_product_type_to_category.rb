class RenameProductTypeToCategory < ActiveRecord::Migration[7.0]
  def change
    rename_table :product_types, :categories
  end
end
