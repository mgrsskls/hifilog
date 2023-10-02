class RenameProductTitleToName < ActiveRecord::Migration[7.0]
  def self.up
    rename_column :products, :title, :name
  end
end
