class ProductItem < ApplicationRecord
  include PgSearch::Model

  self.primary_key = :id # needed for pg_search
  # Tell Rails to use created_at for .first and .last instead of the UUID id
  self.implicit_order_column = 'created_at'

  belongs_to :brand
  has_many :product_options

  pg_search_scope :search,
                  against: {
                    name: 'A',
                    variant_name: 'B',
                    model_no: 'B',
                    brand_name: 'A'
                  },
                  ignoring: :accents,
                  using: {
                    tsearch: {
                      any_word: false,
                      prefix: true,
                    },
                    trigram: {
                      threshold: 0.2
                    },
                  },
                  ranked_by: ':trigram'

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
