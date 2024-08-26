class ChangeBrandsDiscontinuedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :brands, :discontinued, false
  end
end
