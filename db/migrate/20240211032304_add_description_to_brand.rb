class AddDescriptionToBrand < ActiveRecord::Migration[7.1]
  def change
    add_column :brands, :description, :text
  end
end
