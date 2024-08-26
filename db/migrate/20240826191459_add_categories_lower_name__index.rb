class AddCategoriesLowerNameIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :categories, 'lower(name)', name: :index_categories_lower_name_, unique: true
  end
end
