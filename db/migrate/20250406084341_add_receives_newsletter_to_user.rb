class AddReceivesNewsletterToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :receives_newsletter, :boolean, default: true
  end
end
