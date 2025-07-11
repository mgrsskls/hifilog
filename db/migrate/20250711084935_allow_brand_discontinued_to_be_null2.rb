class AllowBrandDiscontinuedToBeNull2 < ActiveRecord::Migration[8.0]
  def change
    change_column_null :brands, :discontinued, true
  end
end
