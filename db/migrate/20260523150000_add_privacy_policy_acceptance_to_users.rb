# frozen_string_literal: true

class AddPrivacyPolicyAcceptanceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :privacy_policy_accepted_at, :datetime
    add_column :users, :privacy_policy_version, :string
  end
end
