class Possession < ApplicationRecord
  belongs_to :user
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  belongs_to :custom_product, optional: true

  has_one :setup_possession, dependent: :destroy
  has_one :setup, through: :setup_possession
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_fill: [320, 320], format: :webp
    attachable.variant :thumb_avif, resize_to_fill: [320, 320], format: :avif
    attachable.variant :large, resize_to_limit: [1200, 1200], format: :webp
    attachable.variant :large_avif, resize_to_limit: [1200, 1200], format: :avif
  end

  validate :validate_image_content_type, :validate_image_file_size, on: :update
  validate :validate_image_content_type, :validate_image_file_size, on: :update

  attr_accessor :delete_image

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      custom_product_id
      image_attachment_id
      image_blob_id
      product_id
      product_variant_id
      setup_id
      setup_possession_id
      user_id
      prev_owned_eq
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[
      product
      product_variant
      setup_possessions
      user
    ]
  end

  def validate_image_content_type
    return unless image.attachment

    unless [
      'image/jpeg',
      'image/webp',
      'image/png',
      'image/gif'
    ].include?(image.attachment.blob.content_type)
      errors.add(:image_content_type, 'has the wrong file type. Please upload only .jpg, .webp, .png or .webp files.')
    end
  end

  def validate_image_file_size
    return unless image.attachment
    return if image.attachment.blob.byte_size < 5_000_000

    errors.add(:image_file_size, 'too big. Please use a file with a maximum of 5 MB.')
  end
end
