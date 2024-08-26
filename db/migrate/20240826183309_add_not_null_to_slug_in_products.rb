class AddNotNullToSlugInProducts < ActiveRecord::Migration[7.1]
  def change
    change_column :products, :slug, :string, null: false
  end
end
