class Category < ActiveHash::Base
  include ActiveHash::Associations

  self.data = [
    { id: 1, name: 'Amplifiers', slug: 'amplifiers' },
    { id: 8, name: 'Vacuum Tubes', slug: 'tubes' },
    { id: 3, name: 'Loudspeakers', slug: 'loudspeakers' },
    { id: 2, name: 'Headphones', slug: 'headphones' },
    { id: 4, name: 'Analog', slug: 'analog' },
    { id: 5, name: 'Digital', slug: 'digital' },
    { id: 7, name: 'Cables', slug: 'cables' },
    { id: 6, name: 'Accessories', slug: 'accessories' }
  ]

  has_many :sub_categories, dependent: :destroy

  def sub_categories
    SubCategory.where(category_id: id)
  end
end
