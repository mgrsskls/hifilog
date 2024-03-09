class RemoveIndexFromScopedSlugs < ActiveRecord::Migration[7.1]
  def change
    remove_index :sub_categories, name: 'index_sub_categories_on_slug'
    remove_index :product_variants, name: 'index_product_variants_on_slug'
  end
end
