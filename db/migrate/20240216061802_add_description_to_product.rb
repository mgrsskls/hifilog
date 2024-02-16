class AddDescriptionToProduct < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :description, :text
  end
end
