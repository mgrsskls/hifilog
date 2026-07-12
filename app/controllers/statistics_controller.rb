# frozen_string_literal: true

class StatisticsController < ApplicationController
  include ApplicationHelper
  include CurrentStatisticsOverview

  before_action :authenticate_user!
  before_action :set_menu

  def current
    load_current_statistics_overview

    @current_longest_products = PossessionPresenterService.map_to_presenters(
      @possessions.with_period.where(period_to: nil).sort_by(&:period_from)
    )

    @current_products_per_cost = StatisticsService.format_currency_with_presenters(
      @current_purchase_by_currency, :price_purchase
    )
  end

  def total
    @possessions = current_user.possessions.for_stats

    @total_amount_of_products = @possessions.size
    @total_amount_of_brands   = @possessions.map(&:brand).uniq.size
    @total_products_per_brand = get_products_per_brand(possessions: @possessions)

    @total_longest_products = PossessionPresenterService.map_to_presenters(
      @possessions.where(prev_owned: true).with_period.where.not(period_to: nil)
                  .or(@possessions.current.with_period)
    ).sort_by(&:duration).reverse

    set_total_financials
  end

  def yearly
    @possessions = current_user.possessions.for_stats

    # Activity Stats
    @products_added_removed_per_year = StatisticsService.yearly_activity_map(@possessions)

    # Average Stats
    averages = StatisticsService.calculate_yearly_averages(@possessions)
    @yearly_amount_of_products  = averages[:products]
    @yearly_amount_of_spendings = averages[:spendings]

    # Financial Matrix
    @yearly_costs = StatisticsService.yearly_financial_matrix(@possessions)
  end

  private

  def set_total_financials
    purchase_data = StatisticsService.aggregate_possessions_by_price_category(@possessions, :price_purchase,
                                                                              :price_purchase_currency)
    sale_data     = StatisticsService.aggregate_possessions_by_price_category(@possessions, :price_sale,
                                                                              :price_sale_currency)

    spendings = StatisticsService.format_currency_aggregation(purchase_data, :price_purchase, :spendings)
    earnings  = StatisticsService.format_currency_aggregation(sale_data, :price_sale, :earnings)

    @total_earnings_and_spendings = StatisticsService.consolidate_currencies(spendings, earnings)
                                                     .sort_by { |group| -(group[:spendings] || 0) }

    @total_products_per_cost = StatisticsService.format_currency_with_presenters(purchase_data, :price_purchase)
  end

  def set_menu
    page_title(I18n.t('headings.insights'))
    @active_menu = :dashboard
    @active_dashboard_menu = :statistics
  end
end
