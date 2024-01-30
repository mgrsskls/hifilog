class SetDiscontinuedOnBrandsToFalseByDefault < ActiveRecord::Migration[7.1]
  def change
    change_column :brands, :discontinued, :boolean, default: false
    change_column :products, :discontinued, :boolean, default: false
  end
end
