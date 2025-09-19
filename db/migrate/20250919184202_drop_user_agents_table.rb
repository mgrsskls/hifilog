class DropUserAgentsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :user_agents
  end
end
