# frozen_string_literal: true

module CurrentStatisticsOverview
  extend ActiveSupport::Concern

  # Joins each possession to the brand behind it, whether that hangs off the product
  # directly or off the variant's product. The joins are written out (rather than via
  # +left_joins+) so the SELECT below can refer to +brands+ by name instead of depending
  # on the aliases Rails generates when the same table is joined twice.
  BRAND_JOIN_SQL = <<~SQL.squish
    LEFT JOIN products ON products.id = possessions.product_id
    LEFT JOIN product_variants ON product_variants.id = possessions.product_variant_id
    LEFT JOIN products variant_products ON variant_products.id = product_variants.product_id
    LEFT JOIN brands ON brands.id = COALESCE(products.brand_id, variant_products.brand_id)
  SQL

  # Mirrors +products_per_brand+, which groups by brand *name* and collapses every
  # custom product into a single "Custom" bucket (CustomProductPresenter#brand_name).
  BRAND_NAME_SQL = <<~SQL.squish
    CASE WHEN possessions.custom_product_id IS NOT NULL THEN 'Custom' ELSE brands.name END
  SQL

  private

  # Full overview. Hydrates every current possession, which +statistics#current+ needs:
  # it renders the per-brand breakdown and builds presenters per currency bucket.
  # Pages that only show counts should use +load_current_statistics_summary+ instead.
  def load_current_statistics_overview(user = current_user, include_spendings: nil)
    return unless user

    include_spendings = current_user == user if include_spendings.nil?

    @possessions = user.possessions.current.for_stats
    @current_products_per_brand = products_per_brand(possessions: @possessions)
    @current_amount_of_products = user_possessions_count(user: user)
    @current_amount_of_brands = @current_products_per_brand.size

    if include_spendings
      @current_purchase_by_currency = StatisticsService.aggregate_possessions_by_price_category(
        @possessions, :price_purchase, :price_purchase_currency
      )
      @current_spendings = StatisticsService.format_currency_aggregation(
        @current_purchase_by_currency, :price_purchase, :spendings
      )
    else
      @current_spendings = []
    end
  end

  # Counts-only variant for the dashboard and the public profile, which render nothing
  # but products_count, brands_count and spendings. Answers all three with aggregates so
  # the page no longer loads (and preloads brand / variant / custom product for) every
  # possession in the collection just to call +.size+ on the result.
  def load_current_statistics_summary(user = current_user, include_spendings: nil)
    return unless user

    include_spendings = current_user == user if include_spendings.nil?

    @current_amount_of_products = user_possessions_count(user: user)
    @current_amount_of_brands = current_brands_count(user)
    @current_spendings = include_spendings ? current_spendings_by_currency(user) : []
  end

  def current_brands_count(user)
    user.possessions
        .current
        .joins(BRAND_JOIN_SQL)
        .pick(Arel.sql("COUNT(DISTINCT #{BRAND_NAME_SQL})")).to_i
  end

  # Same shape as StatisticsService.format_currency_aggregation: [{ currency:, spendings: }].
  # Sorted by currency because the grouped-in-Ruby version inherited whatever order the
  # database happened to return.
  def current_spendings_by_currency(user)
    user.possessions
        .current
        .where.not(price_purchase: nil)
        .where.not(price_purchase_currency: nil)
        .group(:price_purchase_currency)
        .sum(:price_purchase)
        .sort_by { |currency, _total| currency.to_s }
        .map { |currency, total| { currency: currency, spendings: total } }
  end
end
