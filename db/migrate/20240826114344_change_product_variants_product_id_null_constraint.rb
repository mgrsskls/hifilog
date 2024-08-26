class ChangeProductVariantsProductIdNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :product_variants, :product_id, false
  end
end
