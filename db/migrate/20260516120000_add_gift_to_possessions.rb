# frozen_string_literal: true

class AddGiftToPossessions < ActiveRecord::Migration[8.1]
  def change
    add_column :possessions, :gift, :boolean, default: false, null: false
  end
end
