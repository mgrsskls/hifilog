class UseCitextForBrandsName < ActiveRecord::Migration[7.1]
  def change
    change_column :brands, :name, :citext, null: false
    change_column :brands, :slug, :citext, null: false
  end
end
