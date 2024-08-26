class AddBrandsLowerSlugIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :brands, 'lower(slug)', name: :index_brands_lower_slug_, unique: true
  end
end
