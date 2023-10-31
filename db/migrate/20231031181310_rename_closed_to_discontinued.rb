class RenameClosedToDiscontinued < ActiveRecord::Migration[7.0]
  def change
    rename_column :brands, :closed, :discontinued
  end
end
