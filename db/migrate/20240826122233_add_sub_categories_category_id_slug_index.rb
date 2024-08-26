class AddSubCategoriesCategoryIdSlugIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :sub_categories, %w[category_id slug], name: :index_sub_categories_category_id_slug, unique: true
  end
end
