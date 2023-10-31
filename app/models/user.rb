class User < ApplicationRecord
  has_and_belongs_to_many :products
  has_many :rooms

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def self.ransackable_attributes(auth_object = nil)
    [
      "created_at",
      "email",
      "encrypted_password",
      "id",
      "profile_visibility",
      "remember_created_at",
      "reset_password_sent_at",
      "reset_password_token",
      "updated_at",
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    ["products", "rooms"]
  end
end
