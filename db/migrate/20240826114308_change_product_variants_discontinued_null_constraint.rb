class ChangeProductVariantsDiscontinuedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :product_variants, :discontinued, false
  end
end
