class StatisticsController < ApplicationController
  include ApplicationHelper

  before_action :authenticate_user!
  before_action :set_menu

  def current
    current_possessions = current_user.possessions
                                      .where.not(prev_owned: true)
                                      .includes([:product_variant])
                                      .includes([:custom_product])
                                      .includes([product: [:brand]])

    @current_products_per_brand = get_products_per_brand(possessions: current_possessions)

    @current_amount_of_products = user_possessions_count(user: current_user)
    @current_amount_of_brands = @current_products_per_brand.size

    @current_longest_products =
      map_possessions_to_presenter(
        current_possessions
        .where.not(period_from: nil)
        .where(period_to: nil)
        .sort_by(&:period_from)
      )

    purchase_possessions = current_possessions.where.not(price_purchase: nil).group_by(&:price_purchase_currency)
    total_spendings = purchase_possessions.map do |possession|
      {
        currency: possession[0],
        spendings: possession[1].map(&:price_purchase).sum
      }
    end
    @current_spendings = total_spendings.group_by { |h| h[:currency] }.map do |_, hashes|
      hashes.reduce({}) { |merged_hash, h| merged_hash.merge(h) }
    end

    @current_products_per_cost = purchase_possessions.map do |group|
      {
        currency: group[0],
        possessions: map_possessions_to_presenter(group[1]).sort_by(&:price_purchase).reverse
      }
    end
  end

  def total
    add_breadcrumb 'Total'
    possessions = current_user.possessions
                              .includes([:product_variant])
                              .includes([:custom_product])
                              .includes([product: [:brand]])
    @total_products_per_brand = get_products_per_brand(possessions: possessions)

    @total_amount_of_products = possessions.size
    @total_amount_of_brands = possessions.map(&:brand).uniq.size

    @total_longest_products =
      map_possessions_to_presenter(
        possessions.where(prev_owned: true).where.not(period_from: nil).where.not(period_to: nil).or(
          possessions.where(prev_owned: false).where.not(period_from: nil)
        )
      ).sort_by(&:duration).reverse

    purchase_possessions = possessions.where.not(price_purchase: nil)
                                      .where.not(price_purchase_currency: nil)
                                      .group_by(&:price_purchase_currency)
    total_spendings = if purchase_possessions.any?
                        purchase_possessions
                          .map do |possession|
                          {
                            currency: possession[0],
                            spendings: possession[1].map(&:price_purchase).sum
                          }
                        end
                      else
                        []
                      end
    sale_possessions = possessions.where.not(price_sale: nil)
                                  .where.not(price_sale_currency: nil)
                                  .group_by(&:price_sale_currency)
    total_earnings = sale_possessions.map do |possession|
      {
        currency: possession[0],
        earnings: possession[1].map(&:price_sale).sum
      }
    end

    @total_earnings_and_spendings =
      (total_spendings + total_earnings)
      .group_by { |h| h[:currency] }
      .map do |_, hashes|
        hashes.reduce({}) { |merged_hash, h| merged_hash.merge(h) }
      end

    @total_earnings_and_spendings.sort_by do |group|
      -(group[:spendings].presence || 0)
    end

    @total_products_per_cost = purchase_possessions.map do |group|
      {
        currency: group[0],
        possessions: map_possessions_to_presenter(group[1]).sort_by(&:price_purchase).reverse
      }
    end
  end

  def yearly
    add_breadcrumb 'Yearly'
    possessions = current_user.possessions
                              .includes([:product_variant])
                              .includes([:custom_product])
                              .includes([product: [:brand]])
    products_added = possessions.where.not(period_from: nil)
    products_added_removed = products_added.or(
      possessions.where.not(period_to: nil)
    )

    @yearly_spendings = [{
      currency: 'EUR',
      spendings: 5000,
    }]

    years_added_removed = []
    years_added = []
    years_removed = []

    products_added_removed.each do |product|
      if product.period_from.present?
        years_added_removed << product.period_from.year
        years_added << product.period_from.year
      end
      if product.period_to.present?
        years_added_removed << product.period_to.year
        years_removed << product.period_to.year
      end
    end

    products_added_removed_per_year = years_added_removed.uniq.sort.map do |year|
      {
        year:,
        possessions: {
          from: products_added_removed.select do |possession|
            possession.period_from.present? && possession.period_from.year == year
          end,
          to: products_added_removed.select do |possession|
            possession.period_to.present? && possession.period_to.year == year
          end,
        }
      }
    end

    products_added_per_year = years_added.uniq.sort.map do |year|
      {
        year:,
        possessions: {
          from: products_added_removed.select do |possession|
            possession.period_from.present? && possession.period_from.year == year
          end,
        }
      }
    end

    years_removed.uniq.sort.map do |year|
      {
        year:,
        possessions: {
          to: products_added_removed.select do |possession|
            possession.period_to.present? && possession.period_to.year == year
          end,
        }
      }
    end

    @products_added_removed_per_year = products_added_removed_per_year

    if products_added_per_year.any?
      earliest_year = products_added_per_year.pluck(:year).min
      amount_of_years = Time.zone.today.year - earliest_year
      @yearly_amount_of_products = if amount_of_years > 0
                                     products_added.size / amount_of_years.to_f
                                   else
                                     products_added.size
                                   end

      total_spendings = possessions.where.not(price_purchase: nil)
                                   .where.not(price_purchase_currency: nil)
                                   .group_by(&:price_purchase_currency)
                                   .map do |possession|
                                     {
                                       currency: possession[0],
                                       spendings: possession[1].map(&:price_purchase).sum
                                     }
                                     # rubocop:disable Style/MultilineBlockChain
                                   end
                                   # rubocop:enable Style/MultilineBlockChain
                                   .sort_by do |group|
                                     -group[:spendings]
                                   end

      if total_spendings.any?
        @yearly_amount_of_spendings = {
          currency: total_spendings.first[:currency],
          spendings: total_spendings.first[:spendings] / amount_of_years.to_f
        }
      end
    else
      @yearly_amount_of_products = []
      @yearly_amount_of_spendings = {
        currency: 'n/a',
        spendings: 0
      }
    end

    possessions_with_spendings = possessions.where.not(price_purchase: nil)
                                            .where.not(price_purchase_currency: nil)
                                            .where.not(period_from: nil)
    possessions_with_earnings = possessions.where.not(price_sale: nil)
                                           .where.not(price_sale_currency: nil)
                                           .where.not(period_to: nil)

    spendings_currencies = possessions_with_spendings.map(&:price_purchase_currency).compact_blank.uniq
    earnings_currencies = possessions_with_earnings.map(&:price_sale_currency).compact_blank.uniq
    currencies = (spendings_currencies + earnings_currencies).uniq

    spendings_years = possessions_with_spendings.map(&:period_from).compact_blank.uniq
    earnings_years = possessions_with_earnings.map(&:period_to).compact_blank.uniq
    years = (spendings_years + earnings_years).map(&:year).sort.uniq

    @yearly_costs = years.map do |year|
      {
        year:,
        currencies: currencies.map do |c|
          {
            currency: c,
            spendings: possessions_with_spendings.select do |p|
              p.period_from.year == year && p.price_purchase_currency == c && p.price_purchase.present?
            end.map(&:price_purchase).compact.sum,
            earnings: possessions_with_earnings.select do |p|
              p.period_to.year == year && p.price_sale_currency == c && p.price_sale.present?
            end.map(&:price_sale).compact.sum
          }
        end
      }
    end
  end

  private

  def set_menu
    @page_title = I18n.t('headings.statistics')
    @active_menu = :dashboard
    @active_dashboard_menu = :statistics
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
    add_breadcrumb I18n.t('headings.statistics'), dashboard_statistics_root_path
  end
end
