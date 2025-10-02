class AddUniquenessToCustomAttributeLabel < ActiveRecord::Migration[8.0]
  def change
    add_index :custom_attributes, :label, unique: true
  end
end
