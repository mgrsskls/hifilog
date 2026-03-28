class AddsCompositeIndexForBrandsSubCategories < ActiveRecord::Migration[8.1]
  def change
    # Composite index for common filter combinations
    add_index :brands_sub_categories, [:sub_category_id, :brand_id], name: 'idx_brands_sub_categories_reverse'
  end
end
