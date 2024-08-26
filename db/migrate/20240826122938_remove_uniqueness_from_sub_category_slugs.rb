class RemoveUniquenessFromSubCategorySlugs < ActiveRecord::Migration[7.1]
  def change
    remove_index :sub_categories, name: 'index_sub_categories_on_slug'
    add_index :sub_categories, :slug
  end
end
