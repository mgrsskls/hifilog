module Format
  extend ActiveSupport::Concern

  def release_date
    formatted_date(release_day, release_month, release_year)
  end

  def discontinued_date
    return unless discontinued?

    formatted_date(discontinued_day, discontinued_month, discontinued_year)
  end

  def display_price
    "#{number_with_delimiter number_to_rounded(price, precision: 2)} #{price_currency}"
  end

  private

  def formatted_date(day, month, year)
    return nil if year.nil?
    return year.to_s if month.nil?

    formatted_month = month.to_s.rjust(2, '0')

    return "#{formatted_month}/#{year}" if day.nil?

    formatted_day = day.to_s.rjust(2, '0')

    "#{formatted_day}/#{formatted_month}/#{year}"
  end
end
