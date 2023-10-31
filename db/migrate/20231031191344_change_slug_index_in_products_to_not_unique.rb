class ChangeSlugIndexInProductsToNotUnique < ActiveRecord::Migration[7.0]
  def change
    remove_index :products, :slug
    add_index    :products, :slug
  end
end
