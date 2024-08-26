class ChangeProductOptionToCitext < ActiveRecord::Migration[7.1]
  def change
    change_column :product_options, :option, :citext, null: false
  end
end
