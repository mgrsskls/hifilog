class AddReleaseDateToProduct < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :release_date, :date
  end
end
