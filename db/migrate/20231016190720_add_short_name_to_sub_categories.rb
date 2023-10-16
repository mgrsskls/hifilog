class AddShortNameToSubCategories < ActiveRecord::Migration[7.0]
  def change
    add_column :sub_categories, :short_name, :string
  end
end
