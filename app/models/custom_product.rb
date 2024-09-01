class CustomProduct < ApplicationRecord
  belongs_to :user
  has_one :possession, dependent: :destroy
  has_and_belongs_to_many :sub_categories
  has_one_attached :image do |attachable|
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

  def formatted_description
    return if description.blank?

    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(description)
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

    errors.add(:image_file_size, 'is too big. Please use a file with a maximum of 5 MB.')
  end

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
end
