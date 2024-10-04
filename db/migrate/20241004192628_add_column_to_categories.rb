class AddColumnToCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :categories, :column, :int
  end
end
