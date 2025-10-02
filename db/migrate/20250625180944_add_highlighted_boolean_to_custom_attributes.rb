class AddHighlightedBooleanToCustomAttributes < ActiveRecord::Migration[8.0]
  def change
    add_column :custom_attributes, :highlighted, :boolean, default: false unless column_exists?(:custom_attributes, :highlighted)
  end
end
