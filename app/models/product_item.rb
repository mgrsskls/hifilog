# frozen_string_literal: true

class ProductItem < ApplicationRecord
  include PgSearch::Model
  include ReleaseDate
  include PgSearchByName

  self.primary_key = :id # needed for pg_search
  # Tell Rails to use created_at for .first and .last instead of the UUID id
  self.implicit_order_column = 'created_at'

  belongs_to :brand
  has_many :product_options

  pg_search_by_name(against: {
                      name: 'A',
                      variant_name: 'B',
                      model_no: 'B',
                      brand_name: 'A'
                    })

  def readonly?
    true
  end

  def sub_categories
    SubCategory.joins(:products).where(products: { id: product_id }).distinct
  end
end
