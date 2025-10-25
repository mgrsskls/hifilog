class SearchResult < ApplicationRecord
  include PgSearch::Model

  self.primary_key = :id # needed for pg_search

  pg_search_scope :search,
                  against: {
                    product_name: 'A',
                    product_variant_name: 'A',
                    brand_name: 'A',
                    model_no: 'B'
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
end
