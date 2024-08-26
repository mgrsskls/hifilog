class AddNotNullToSubCategories < ActiveRecord::Migration[7.1]
  def change
    change_column :sub_categories, :name, :string, null: false
    change_column :sub_categories, :slug, :string, null: false
  end
end
