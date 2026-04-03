# frozen_string_literal: true

class SearchResult < ApplicationRecord
  include PgSearch::Model
  include PgSearchByName

  self.primary_key = :id # needed for pg_search
  self.implicit_order_column = :id

  pg_search_by_name(against: {
                      product_name: 'A',
                      product_variant_name: 'A',
                      brand_name: 'A',
                      model_no: 'B'
                    })

  def readonly?
    true
  end
end
