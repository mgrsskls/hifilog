class User < ApplicationRecord
  include Rails.application.routes.url_helpers

  strip_attributes

  enum profile_visibility: {
    hidden: 0,
    logged_in_only: 1,
    visible: 2,
  }

  has_and_belongs_to_many :products
  has_many :setups, dependent: :destroy
  has_many :bookmarks, dependent: :destroy

  validates :user_name, uniqueness: true, allow_nil: true
  validates :user_name, presence: true, if: :public_profile?

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

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
      user_name
      confirmation_token
      unconfirmed_email
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[products setups]
  end

  def profile_path
    return if user_name.nil?

    user_path(user_name)
  end

  private

  def public_profile?
    profile_visibility != 'hidden'
  end
end
