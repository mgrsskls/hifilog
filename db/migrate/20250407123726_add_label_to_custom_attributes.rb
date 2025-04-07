class AddLabelToCustomAttributes < ActiveRecord::Migration[8.0]
  def change
    add_column :custom_attributes, :label, :string
  end
end
