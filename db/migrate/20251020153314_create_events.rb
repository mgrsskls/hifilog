class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string :name
      t.string :url
      t.text :address
      t.string :country_code
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
  end
end
