class AddUserAndAppNewsJoinTable < ActiveRecord::Migration[7.1]
  def change
    create_join_table :app_news, :users
  end
end
