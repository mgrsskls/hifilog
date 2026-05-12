# frozen_string_literal: true

class AddPurchaseConditionToPossessions < ActiveRecord::Migration[8.1]
  def change
    add_column :possessions, :purchase_condition, :integer, null: true
  end
end
