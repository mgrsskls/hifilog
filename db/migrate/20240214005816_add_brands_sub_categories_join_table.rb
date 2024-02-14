class AddBrandsSubCategoriesJoinTable < ActiveRecord::Migration[7.1]
  def change
    create_join_table :brands, :sub_categories
  end
end
