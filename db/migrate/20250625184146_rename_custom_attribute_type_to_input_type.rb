class RenameCustomAttributeTypeToInputType < ActiveRecord::Migration[8.0]
  def change
    rename_column :custom_attributes, :type, :input_type
  end
end
