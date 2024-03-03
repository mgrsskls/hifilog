class ProductVariant < ApplicationRecord
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper

  belongs_to :product

  validates :price,
            numericality: true,
            comparison: { greater_than: 0 },
            if: -> { price.present? }
  validates :price_currency,
            presence: true,
            if: -> { price.present? }
  validates :release_day,
            numericality: { only_integer: true },
            comparison: { greater_than: 0, less_than: 32 },
            if: -> { release_day.present? }
  validates :release_month,
            numericality: { only_integer: true },
            comparison: { greater_than: 0, less_than: 13 },
            if: -> { release_month.present? }
  validates :release_year,
            numericality: { only_integer: true },
            comparison: { greater_than: 1899 },
            if: -> { release_year.present? }

  def release_date
    return nil if release_year.nil?
    return release_year.to_s if release_month.nil?

    formatted_month = release_month.to_s.rjust(2, '0')

    return "#{formatted_month}/#{release_year}" if release_day.nil?

    formatted_day = release_day.to_s.rjust(2, '0')

    "#{formatted_day}/#{formatted_month}/#{release_year}"
  end

  def display_price
    "#{number_with_delimiter number_to_rounded(price, precision: 2)} #{price_currency}"
  end
end
