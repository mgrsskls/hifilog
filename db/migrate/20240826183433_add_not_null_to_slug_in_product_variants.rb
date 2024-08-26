class AddNotNullToSlugInProductVariants < ActiveRecord::Migration[7.1]
  def change
    change_column :product_variants, :slug, :string, null: false
  end
end
