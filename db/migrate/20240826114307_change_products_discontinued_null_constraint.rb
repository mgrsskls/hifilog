class ChangeProductsDiscontinuedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :products, :discontinued, false
  end
end
