class AddPerformanceIndexesToEvents < ActiveRecord::Migration[8.1]
  def change
    # 1. Index for date-based lookups (Upcoming and Past)
    # Using a composite index helps with the 'OR' logic and range queries
    add_index :events, [:end_date, :start_date]

    # 2. Index for the country filter and the .distinct.pluck lookup
    add_index :events, :country_code
  end
end
