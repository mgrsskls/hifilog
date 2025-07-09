class CreateProductItems < ActiveRecord::Migration[8.0]
  def change
    create_view :product_items
  end
end
