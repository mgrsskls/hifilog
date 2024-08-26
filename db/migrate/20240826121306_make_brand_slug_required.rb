class MakeBrandSlugRequired < ActiveRecord::Migration[7.1]
  def change
    change_column :brands, :slug, :string, null: false
  end
end
