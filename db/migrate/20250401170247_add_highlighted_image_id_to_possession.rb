class AddHighlightedImageIdToPossession < ActiveRecord::Migration[8.0]
  def change
    add_column :possessions, :highlighted_image_id, :bigint
  end
end
