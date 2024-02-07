class RemoveReleaseDateFromProduct < ActiveRecord::Migration[7.1]
  def change
    remove_column :products, :release_date
  end
end
