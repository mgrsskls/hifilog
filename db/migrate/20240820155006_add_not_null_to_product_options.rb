class AddNotNullToProductOptions < ActiveRecord::Migration[7.1]
  def change
    change_column :product_options, :option, :string, null: false
  end
end
