class AddIndexToCustomAttributesOnProducts < ActiveRecord::Migration[7.1]
  def change
    add_index :products, :custom_attributes, using: :gin
  end
end
