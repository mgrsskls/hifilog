class AllowBrandDiscontinuedToBeNull < ActiveRecord::Migration[8.0]
  def change
    change_column_default :brands, :discontinued, nil
  end
end
