# frozen_string_literal: true

class User < ApplicationRecord
  require 'mini_magick'

  include Rails.application.routes.url_helpers

  strip_attributes

  enum :profile_visibility, {
    hidden: 0,
    logged_in_only: 1,
    visible: 2
  }

  has_many :user_activities, dependent: :destroy
  has_many :possessions, dependent: :destroy
  has_many :products, through: :possessions
  has_many :product_variants, through: :possessions
  has_many :setups, dependent: :destroy
  has_many :setup_possessions, through: :setups
  has_many :bookmarks, dependent: :destroy
  has_many :bookmark_lists, dependent: :destroy
  has_many :custom_products, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_and_belongs_to_many :app_news
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [320, 320], format: :webp
  end
  has_one_attached :decorative_image do |attachable|
    attachable.variant :thumb, resize_to_fill: [193, 40], format: :webp
    attachable.variant :large, resize_to_fill: [1512, 314], format: :webp
  end
  has_many :event_attendees, dependent: :destroy
  has_many :events, through: :event_attendees

  auto_strip_attributes :user_name, squish: true

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :confirmation_token, uniqueness: true, allow_nil: true
  validates :reset_password_token, uniqueness: true, allow_nil: true
  validates :user_name, presence: true, uniqueness: { case_sensitive: false }
  validate :validate_avatar_content_type, :validate_avatar_file_size, on: :update
  validate :validate_decorative_image_content_type, :validate_decorative_image_file_size, on: :update

  after_commit :invalidate_cache
  after_commit :record_profile_image_upload_activities, on: :update

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  def profile_path
    user_path(user_name.downcase)
  end

  def assign_attributes(new_attributes)
    capture_profile_image_attachment_ids_before_assign(new_attributes) if persisted?
    super
  end

  def purge_avatar!
    return unless avatar.attached?

    UserActivities::Recorder.avatar_deleted(self, image_attachment: avatar.attachment)
    avatar.purge
  end

  def purge_decorative_image!
    return unless decorative_image.attached?

    UserActivities::Recorder.decorative_image_deleted(self, image_attachment: decorative_image.attachment)
    decorative_image.purge
  end

  def lowercase_user_name
    user_name.downcase
  end

  def validate_avatar_content_type
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

  def validate_avatar_file_size
    return unless avatar.attachment
    return if avatar.attachment.blob.byte_size < 5_000_000

    errors.add(:avatar_file_size, 'is too big. Please use a file with a maximum of 5 MB.')
  end

  def validate_decorative_image_content_type
    return unless decorative_image.attachment

    unless [
      'image/jpeg',
      'image/webp',
      'image/png',
      'image/gif'
    ].include?(decorative_image.attachment.blob.content_type)
      errors.add(
        :decorative_image_content_type,
        'has the wrong file type. Please upload only .jpg, .webp, .png or .webp files.'
      )
    end
  end

  def validate_decorative_image_file_size
    return unless decorative_image.attachment
    return if decorative_image.attachment.blob.byte_size < 5_000_000

    errors.add(:decorative_image_file_size, 'is too big. Please use a file with a maximum of 5 MB.')
  end

  def capture_profile_image_attachment_ids_before_assign(new_attributes)
    attrs = new_attributes.stringify_keys
    @avatar_attachment_id_before_save = avatar.attachment&.id if attrs.key?('avatar')
    return unless attrs.key?('decorative_image')

    @decorative_image_attachment_id_before_save = decorative_image.attachment&.id
  end

  def record_profile_image_upload_activities
    record_profile_image_changes(:avatar, @avatar_attachment_id_before_save)
    record_profile_image_changes(:decorative_image, @decorative_image_attachment_id_before_save)
  ensure
    @avatar_attachment_id_before_save = nil
    @decorative_image_attachment_id_before_save = nil
  end

  def record_profile_image_changes(attachment_name, before_id)
    attachment = public_send(attachment_name).attachment
    current_id = attachment&.id

    if before_id.present? && before_id != current_id
      UserActivities::Recorder.public_send(
        "#{attachment_name}_deleted", self, image_attachment_id: before_id
      )
    end

    return unless current_id.present? && current_id != before_id

    UserActivities::Recorder.public_send(
      "#{attachment_name}_uploaded", self, image_attachment: attachment
    )
  end

  private :capture_profile_image_attachment_ids_before_assign,
          :record_profile_image_upload_activities,
          :record_profile_image_changes

  # rubocop:disable Naming/PredicateMethod
  def invalidate_cache
    # rubocop:enable Naming/PredicateMethod
    Rails.cache.delete('/newest_users')

    # recommended to return true, as Rails.cache.delete will return false
    # if no cache is found and break the callback chain.
    # rubocop:disable Style/RedundantReturn
    return true
    # rubocop:enable Style/RedundantReturn
  end

  # This is used for dropdowns in active_admin
  # :nocov:
  def display_name
    email
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      bookmark_lists_id
      user_name
      user_name_cont
      user_name_end
      user_name_eq
      user_name_start
      receives_newsletter
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # :nocov:
end
