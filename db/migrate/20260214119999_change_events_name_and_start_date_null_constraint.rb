# frozen_string_literal: true

class ChangeEventsNameAndStartDateNullConstraint < ActiveRecord::Migration[8.1]
  def change
    change_column_null :events, :name, false
    change_column_null :events, :start_date, false
  end
end
