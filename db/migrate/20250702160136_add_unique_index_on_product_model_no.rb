class AddUniqueIndexOnProductModelNo < ActiveRecord::Migration[8.0]
  def change
    add_index :products, [:model_no, :brand_id], unique: true
  end
end
