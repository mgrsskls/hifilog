class CustomProduct < ApplicationRecord
  has_one :possession, dependent: :destroy
  has_one :user, through: :possession
  has_and_belongs_to_many :sub_categories

  validates :name, presence: true
  validates :sub_categories, presence: true

  def custom_attributes
    {}
  end

  def built_in
    2020
  end

  def formatted_description
    return if description.blank?

    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(description)
  end
end
