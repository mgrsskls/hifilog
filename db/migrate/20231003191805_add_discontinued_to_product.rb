class AddDiscontinuedToProduct < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :discontinued, :boolean
  end
end
