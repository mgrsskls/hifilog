class ChangeUsersReceivesNewsletterNullConstraint < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :receives_newsletter, false
  end
end
