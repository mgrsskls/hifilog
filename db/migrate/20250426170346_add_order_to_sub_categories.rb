class AddOrderToSubCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :sub_categories, :order, :integer
  end
end
