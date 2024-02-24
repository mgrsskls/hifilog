class RemoveNameFromCustomAttributes < ActiveRecord::Migration[7.1]
  def change
    remove_column :custom_attributes, :name
  end
end
