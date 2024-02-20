class User < ApplicationRecord
  require 'mini_magick'

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
  has_many :prev_owneds, dependent: :destroy
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [76, 76], format: :webp
  end

  validates :user_name, presence: true, uniqueness: true
  validate :validate_avatar_content_type, :validate_avatar_file_size, on: :update

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
      bookmarks_id
      prev_owneds_id
      avatar_attachment_id
      avatar_blob_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[products setups]
  end

  def profile_path
    return if user_name.nil?

    user_path(user_name)
  end

  def validate_avatar_content_type
    unless [
      'image/jpeg',
      'image/webp',
      'image/png',
      'image/gif'
    ].include?(avatar.attachment.blob.content_type)
      errors.add(:avatar_content_type, 'has the wrong file type. Please upload only .jpg, .webp, .png or .webp files.')
    end
  end

  def validate_avatar_file_size
    return if avatar.attachment.blob.byte_size < 5_000_000

    errors.add(:avatar_file_size, 'too big. Please use a file with a maximum of 5 MB.')
  end
end
