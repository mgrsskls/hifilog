class CreateProductOptions < ActiveRecord::Migration[7.1]
  def change
    create_table :product_options do |t|
      t.string :option
      t.bigint :product_id
      t.bigint :product_variant_id

      t.timestamps
    end
  end
end
