class AddUserAgentTable < ActiveRecord::Migration[8.0]
  def change
    create_table :user_agents do |t|
      t.string :user_agent
      t.timestamps
    end
  end
end
