# frozen_string_literal: true

# Devise lockable for admin users with the :time unlock strategy, so there is no unlock_token.
# See docs/privacy-auth-security.md, "Authentication and admin".
class AddLockableToAdminUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :admin_users, bulk: true do |t|
      t.integer :failed_attempts, default: 0, null: false
      t.datetime :locked_at
    end
  end
end
