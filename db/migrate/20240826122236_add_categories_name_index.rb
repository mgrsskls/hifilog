class AddCategoriesNameIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :categories, :name, name: :index_categories_name, unique: true
  end
end
