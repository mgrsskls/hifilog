class CreateProductVariants < ActiveRecord::Migration[7.1]
  def change
    create_table :product_variants do |t|
      t.string :name
      t.text :description
      t.integer :year

      t.timestamps
    end
  end
end
