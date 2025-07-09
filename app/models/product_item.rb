class ProductItem < ApplicationRecord
  belongs_to :brand
  has_many :product_options

  def readonly?
    true
  end

  def sub_categories
    SubCategory.joins(:products).where(products: { id: product_id }).distinct
  end

  def release_date
    return if release_year.blank?

    Date.new(release_year.to_i, release_month.present? ? release_month.to_i : 1,
             release_day.present? ? release_day.to_i : 1)
  end
end
