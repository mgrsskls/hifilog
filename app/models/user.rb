class User < ApplicationRecord
  include Rails.application.routes.url_helpers

  before_create :assing_random_username

  has_and_belongs_to_many :products
  has_many :setups, dependent: :destroy

  validates :user_name, uniqueness: { allow_blank: true }

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      email
      encrypted_password
      id
      profile_visibility
      remember_created_at
      reset_password_sent_at
      reset_password_token
      updated_at
      random_username
      user_name
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[products setups]
  end

  def display_name
    return user_name if user_name.present?

    random_username
  end

  def profile_path
    return username_path(username: user_name) if user_name.present?

    random_username_path(random_username:)
  end

  private

  def assing_random_username
    self.random_username = SecureRandom.alphanumeric(8)
  end
end
