class AddPeriodToPossesion < ActiveRecord::Migration[7.1]
  def change
    add_column :possessions, :period_from, :datetime
    add_column :possessions, :period_to, :datetime
  end
end
