class AddFullNameToBrands < ActiveRecord::Migration[7.1]
  def change
    add_column :brands, :full_name, :string
  end
end
