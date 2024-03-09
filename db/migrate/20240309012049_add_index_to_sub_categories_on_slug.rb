class AddIndexToSubCategoriesOnSlug < ActiveRecord::Migration[7.1]
  def change
    add_index :sub_categories, :slug, unique: true
  end
end
