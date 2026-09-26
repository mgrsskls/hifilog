# frozen_string_literal: true

class AdminUser < ApplicationRecord
  # Lockable unlocks after a time only: an unlock email would need its own page, throttle and
  # mailer view. To unlock earlier, use AdminUser#unlock_access! in a console.
  # See docs/privacy-auth-security.md#1-authentication-and-admin.
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable,
         :lockable, unlock_strategy: :time, unlock_in: 1.hour

  # simplecov:disable
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      email
      id
      remember_created_at
      reset_password_sent_at
      reset_password_token
      updated_at
    ]
  end
  # simplecov:enable
end
