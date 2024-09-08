class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  # :nocov:
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
  # :nocov:
end
