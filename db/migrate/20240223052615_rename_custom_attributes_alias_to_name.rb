class RenameCustomAttributesAliasToName < ActiveRecord::Migration[7.1]
  def change
    rename_column :custom_attributes, :alias, :name
  end
end
