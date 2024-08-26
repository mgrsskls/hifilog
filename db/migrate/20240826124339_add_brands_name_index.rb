class AddBrandsNameIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :brands, :name, name: :index_brands_name, unique: true
  end
end
