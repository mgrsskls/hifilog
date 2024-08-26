class AddUniquenessToCategorySlug < ActiveRecord::Migration[7.1]
  def change
    change_column :categories, :slug, :string, null: false
  end
end
