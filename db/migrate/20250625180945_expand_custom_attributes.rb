class ExpandCustomAttributes < ActiveRecord::Migration[8.0]
  def change
    add_column :custom_attributes, :type, :string
    add_column :custom_attributes, :inputs, :string, array: true, default: []
    add_column :custom_attributes, :units, :string, array: true, default: []
  end
end
