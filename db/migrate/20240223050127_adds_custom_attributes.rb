class AddsCustomAttributes < ActiveRecord::Migration[7.1]
  def change
    create_table :custom_attributes do |t|
      t.string 'alias'
      t.jsonb 'options'
    end

    add_column :sub_categories, :custom_attributes, :integer, array: true
    add_column :products, :custom_attributes, :jsonb
  end
end
