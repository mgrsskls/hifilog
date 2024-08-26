class AddCategoriesLowerSlugIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :categories, 'lower(slug)', name: :index_categories_lower_slug_, unique: true
  end
end
