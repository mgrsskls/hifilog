class AddSubCategoryToProduct < ActiveRecord::Migration[7.0]
  def change
    add_reference :products, :sub_category, foreign_key: true
  end
end
