# frozen_string_literal: true

class StatisticsService
  def self.aggregate_possessions_by_price_category(possessions, price_field, currency_field)
    possessions
      .where.not(price_field => nil)
      .where.not(currency_field => nil)
      .group_by { |possession| possession.send(currency_field) }
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

  # Merges multiple currency hashes (e.g., spendings and earnings) into one per currency
  def self.consolidate_currencies(*data_arrays)
    data_arrays.flatten
               .group_by { |hash| hash[:currency] }
               .map do |_, hashes|
                 hashes.reduce({}) { |merged, hash| merged.merge(hash) }
               end
  end

  def self.calculate_yearly_averages(possessions)
    products_added = possessions.with_period
    return { products: 0, spendings: { currency: 'n/a', spendings: 0 } } if products_added.empty?

    earliest_year = products_added.minimum(:period_from).year
    years_count = [Time.zone.today.year - earliest_year, 1].max.to_f

    {
      products: products_added.size / years_count,
      spendings: calculate_top_spending_average(possessions, years_count)
    }
  end

  # Logic for the "Products added/removed per year" chart
  def self.yearly_activity_map(possessions)
    # Get all products that have at least one date defined
    possessions = possessions.where.not(period_from: nil)
                             .or(possessions.where.not(period_to: nil))

    # Identify all unique years involved in both additions and removals
    years = possessions.pluck(:period_from, :period_to)
                       .flatten.compact.map(&:year).uniq.sort

    years.map do |year|
      {
        year: year,
        possessions: {
          from: possessions.select { |possession| possession.period_from&.year == year },
          to: possessions.select { |possession| possession.period_to&.year == year }
        }
      }
    end
  end

  # Logic for the "Yearly Costs/Earnings" financial matrix
  def self.yearly_financial_matrix(possessions)
    # Use separate where.not calls to ensure BOTH fields are present (AND logic)
    with_spendings = possessions.where.not(price_purchase: nil).where.not(period_from: nil)
    with_earnings  = possessions.where.not(price_sale: nil).where.not(period_to: nil)

    # Use .compact to safely handle any nils before calling .year
    spending_years = with_spendings.pluck(:period_from).compact.map(&:year)
    earning_years  = with_earnings.pluck(:period_to).compact.map(&:year)

    years = (spending_years + earning_years).uniq.sort

    # Pull unique currencies
    currencies = (with_spendings.pluck(:price_purchase_currency) +
                  with_earnings.pluck(:price_sale_currency)).uniq.compact

    # Pre-group data into hashes for O(1) lookup
    spendings_lookup = with_spendings.group_by do |possession|
      [possession.period_from.year, possession.price_purchase_currency]
    end
    earnings_lookup = with_earnings.group_by do |possession|
      [possession.period_to.year, possession.price_sale_currency]
    end

    years.map do |year|
      {
        year: year,
        currencies: currencies.map do |currency|
          {
            currency: currency,
            spendings: (spendings_lookup[[year, currency]] || []).sum(&:price_purchase),
            earnings: (earnings_lookup[[year, currency]] || []).sum(&:price_sale)
          }
        end
      }
    end
  end

  def self.calculate_top_spending_average(possessions, years_count)
    top_spending = possessions.where.not(price_purchase: nil)
                              .group(:price_purchase_currency)
                              .sum(:price_purchase)
                              .first # Returns [currency, sum]

    return { currency: 'n/a', spendings: 0 } unless top_spending

    { currency: top_spending[0], spendings: top_spending[1] / years_count }
  end
end
