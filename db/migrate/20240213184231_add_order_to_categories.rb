class AddOrderToCategories < ActiveRecord::Migration[7.1]
  def change
    add_column :categories, :order, :integer
  end
end
