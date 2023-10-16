class RemoveShortNameToSubCategories < ActiveRecord::Migration[7.0]
  def change
    remove_column :sub_categories, :short_name
  end
end
