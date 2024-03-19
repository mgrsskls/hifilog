class CreateNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :notes do |t|
      t.text :text
      t.bigint :product_id
      t.bigint :product_variant_id

      t.timestamps
    end
  end
end
