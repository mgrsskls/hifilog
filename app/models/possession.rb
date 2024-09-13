class Possession < ApplicationRecord
  include Image

  belongs_to :user
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  belongs_to :custom_product, optional: true
  belongs_to :product_option, optional: true

  has_one :setup_possession, dependent: :destroy
  has_one :setup, through: :setup_possession
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_fill: [320, 320], format: :webp
    attachable.variant :large, resize_to_limit: [1200, 1200], format: :webp
  end

  validate :validate_image_content_type, :validate_image_file_size, on: :update

  attr_accessor :delete_image

  def brand
    return product_variant.product.brand if product_variant.present?
    return product.brand if product.present?

    nil
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      user_id
      user_id_eq
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # :nocov:
end
