class CreateAppNews < ActiveRecord::Migration[7.1]
  def change
    create_table :app_news do |t|
      t.text :text, null: false

      t.timestamps
    end
  end
end
