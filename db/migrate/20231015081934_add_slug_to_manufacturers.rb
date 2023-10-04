class AddSlugToManufacturers < ActiveRecord::Migration[7.0]
  def change
    add_column :manufacturers, :slug, :string
    add_index :manufacturers, :slug, unique: true
  end
end
