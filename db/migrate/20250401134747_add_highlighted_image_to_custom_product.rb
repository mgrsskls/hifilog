class AddHighlightedImageToCustomProduct < ActiveRecord::Migration[8.0]
  def change
    add_column :custom_products, :highlighted_image, :bigint
  end
end
