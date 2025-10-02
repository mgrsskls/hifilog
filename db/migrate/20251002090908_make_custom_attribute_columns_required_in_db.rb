class MakeCustomAttributeColumnsRequiredInDb < ActiveRecord::Migration[8.0]
  def change
    change_column :custom_attributes, :label, :string, null: false
    change_column :custom_attributes, :highlighted, :boolean, null: false
  end
end
