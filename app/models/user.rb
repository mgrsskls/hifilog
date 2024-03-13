class User < ApplicationRecord
  require 'mini_magick'

  include Rails.application.routes.url_helpers

  strip_attributes

  enum profile_visibility: {
    hidden: 0,
    logged_in_only: 1,
    visible: 2,
  }

  has_many :possessions, dependent: :destroy
  has_many :products, through: :possessions
  has_many :product_variants, through: :possessions
  has_many :setups, dependent: :destroy
  has_many :setup_possessions, through: :setups
  has_many :bookmarks, dependent: :destroy
  has_many :prev_owneds, dependent: :destroy
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [320, 320], format: :webp
    attachable.variant :thumb_avif, resize_to_limit: [320, 320], format: :avif
  end
  has_one_attached :decorative_image do |attachable|
    attachable.variant :thumb, resize_to_limit: [193, 314], format: :webp
    attachable.variant :thumb_avif, resize_to_limit: [193, 314], format: :avif
    attachable.variant :large, resize_to_limit: [1512, 314], format: :webp
    attachable.variant :large_avif, resize_to_limit: [1512, 314], format: :avif
  end

  validates :user_name, presence: true, uniqueness: true
  validate :validate_image_content_type, :validate_image_file_size, on: :update
  validate :validate_image_content_type, :validate_image_file_size, on: :update

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      avatar_attachment_id
      avatar_blob_id
      bookmarks_id
      confirmation_token
      created_at
      decorative_image_attachment_id
      decorative_image_blob_id
      email
      encrypted_password
      id
      possessions_id
      possessions_product_id
      prev_owneds_id
      product_variants_id
      profile_visibility
      remember_created_at
      reset_password_sent_at
      reset_password_token
      setup_possessions_id
      unconfirmed_email
      updated_at
      user_name
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[products setups]
  end

  def profile_path
    return if user_name.nil?

    user_path(user_name.downcase)
  end

  def validate_image_content_type
    return unless avatar.attachment

    unless [
      'image/jpeg',
      'image/webp',
      'image/png',
      'image/gif'
    ].include?(avatar.attachment.blob.content_type)
      errors.add(:avatar_content_type, 'has the wrong file type. Please upload only .jpg, .webp, .png or .webp files.')
    end
  end

  def validate_image_file_size
    return unless avatar.attachment
    return if avatar.attachment.blob.byte_size < 5_000_000

    errors.add(:avatar_file_size, 'too big. Please use a file with a maximum of 5 MB.')
  end
end
