class AddSubCategoriesCategoryIdNameIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :sub_categories, %w[category_id name], name: :index_sub_categories_category_id_name, unique: true
  end
end
