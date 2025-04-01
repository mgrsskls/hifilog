class RenameHighlightedImageToHighlightedImageId < ActiveRecord::Migration[8.0]
  def change
    rename_column :custom_products, :highlighted_image, :highlighted_image_id
  end
end
