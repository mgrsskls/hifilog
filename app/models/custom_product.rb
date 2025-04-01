class CustomProduct < ApplicationRecord
  include Description
  include Image

  belongs_to :user
  has_one :possession, dependent: :destroy
  has_and_belongs_to_many :sub_categories
  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_fill: [320, 320], format: :webp
    attachable.variant :large, resize_to_limit: [1200, 1200], format: :webp
  end

  auto_strip_attributes :name, squish: true

  validates :name, presence: true, uniqueness: { scope: :user }
  validates :sub_categories, presence: true
  validate :validate_image_content_type, :validate_image_file_size, on: :update

  attr_accessor :delete_image

  def custom_attributes
    {}
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      description
      id
      id_value
      name
      updated_at
      user_id
      user_id_eq
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[
      user
    ]
  end
  # :nocov:
end
