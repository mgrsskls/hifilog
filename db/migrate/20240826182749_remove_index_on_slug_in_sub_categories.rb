class RemoveIndexOnSlugInSubCategories < ActiveRecord::Migration[7.1]
  def change
    remove_index :sub_categories, name: 'index_sub_categories_on_slug'
  end
end
