class AddSubCategoriesCustomAttributesJoinTabl < ActiveRecord::Migration[7.1]
  def change
    create_join_table :sub_categories, :custom_attributes
    remove_column :sub_categories, :custom_attributes
  end
end
