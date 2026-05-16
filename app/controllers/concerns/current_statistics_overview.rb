# frozen_string_literal: true

module CurrentStatisticsOverview
  extend ActiveSupport::Concern

  private

  def load_current_statistics_overview
    @possessions = current_user.possessions.current.for_stats
    @current_products_per_brand = get_products_per_brand(possessions: @possessions)
    @current_amount_of_products = user_possessions_count(user: current_user)
    @current_amount_of_brands = @current_products_per_brand.size

    @current_purchase_by_currency = StatisticsService.aggregate_possessions_by_price_category(
      @possessions, :price_purchase, :price_purchase_currency
    )
    @current_spendings = StatisticsService.format_currency_aggregation(
      @current_purchase_by_currency, :price_purchase, :spendings
    )
  end
end
