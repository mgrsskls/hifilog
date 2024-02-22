class DropCategoriesTable < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :sub_categories, column: :category_id
    drop_table :categories
  end
end
