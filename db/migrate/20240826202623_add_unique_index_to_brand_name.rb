class AddUniqueIndexToBrandName < ActiveRecord::Migration[7.1]
  def change
    add_index :brands, :name, unique: true
  end
end
