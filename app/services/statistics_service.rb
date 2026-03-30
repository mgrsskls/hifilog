# frozen_string_literal: true

class StatisticsService
  def self.aggregate_possessions_by_price_category(possessions, price_field, currency_field)
    possessions
      .where.not(price_field => nil)
      .where.not(currency_field => nil)
      .group_by { |p| p.send(currency_field) }
  end

  def self.format_currency_aggregation(grouped_possessions, amount_field, key_name)
    grouped_possessions.map do |currency, possessions|
      {
        currency: currency,
        key_name => possessions.map(&amount_field).sum
      }
    end
  end

  def self.format_currency_with_presenters(grouped_possessions, amount_field)
    grouped_possessions.map do |currency, possessions|
      {
        currency: currency,
        possessions: PossessionPresenterService.map_to_presenters(possessions).sort_by(&amount_field).reverse
      }
    end
  end
end
