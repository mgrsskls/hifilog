class User < ApplicationRecord
  include Rails.application.routes.url_helpers

  before_create :assing_random_username

  has_and_belongs_to_many :products
  has_many :setups

  validates_uniqueness_of :user_name, allow_blank: true

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
    ["products", "setups"]
  end

  def display_name
    return self.user_name if self.user_name.present?
    return self.random_username
  end

  def profile_path
    return username_path(username: self.user_name) if self.user_name.present?
    return random_username_path(random_username: self.random_username)
  end

  private

  def assing_random_username
    self.random_username = SecureRandom.alphanumeric(8)
  end
end
