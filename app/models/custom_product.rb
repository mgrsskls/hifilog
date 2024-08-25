class CustomProduct < ApplicationRecord
  belongs_to :user
  has_one :possession, dependent: :destroy
  has_and_belongs_to_many :sub_categories

  validates :name, presence: true
  validates :sub_categories, presence: true
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_fill: [320, 320], format: :webp
    attachable.variant :large, resize_to_limit: [1200, 1200], format: :webp
  end

  attr_accessor :delete_image

  def custom_attributes
    {}
  end

  def formatted_description
    return if description.blank?

    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(description)
  end
end
