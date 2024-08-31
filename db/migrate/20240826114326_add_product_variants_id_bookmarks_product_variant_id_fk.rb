class AddProductVariantsIdBookmarksProductVariantIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :bookmarks, :product_variants, column: :product_variant_id, primary_key: :id
  end
end