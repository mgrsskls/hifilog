class ChangeBrandsNameNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :brands, :name, false
  end
end
