# frozen_string_literal: true

module DiscontinuedDate
  extend ActiveSupport::Concern

  include DateFromComponents

  def discontinued_date
    return unless discontinued?

    date_from_components(discontinued_year, discontinued_month, discontinued_day)
  end
end
