class UseCitextForCategoriesName < ActiveRecord::Migration[7.1]
  def change
    change_column :categories, :name, :citext, null: false
    change_column :categories, :slug, :citext, null: false
  end
end
