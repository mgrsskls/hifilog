# frozen_string_literal: true

require 'test_helper'

class StatisticsServiceTest < ActiveSupport::TestCase
  test 'consolidate currencies merges keyed stats per denomination' do
    merged = StatisticsService.consolidate_currencies(
      [{ currency: 'USD', spendings: 10 }],
      [{ currency: 'USD', earnings: 4 }],
      [{ currency: 'EUR', earnings: 1 }]
    )

    totals = merged.index_by { |row| row[:currency] }

    assert_equal({ currency: 'USD', spendings: 10, earnings: 4 }, totals['USD'])
    assert_equal({ currency: 'EUR', earnings: 1 }, totals['EUR'])
  end

  test 'calculate yearly averages emits neutral payload without dated possessions' do
    result = StatisticsService.calculate_yearly_averages(Possession.none)

    assert_equal({ products: 0, spendings: { currency: 'n/a', spendings: 0 } }, result)
  end

  test 'aggregate possessions groups sums by currencies' do
    possession = possessions(:current_product)

    possession.update!(
      price_purchase: BigDecimal('199.95'),
      price_purchase_currency: 'USD'
    )

    grouped = StatisticsService.aggregate_possessions_by_price_category(
      Possession.where(id: possession.id),
      :price_purchase,
      :price_purchase_currency
    )

    assert_operator grouped.keys.count, :>=, 1

    grouped.each_value do |list|
      assert(list.all? { |p| p.price_purchase.present? })
    end

    totals = StatisticsService.format_currency_aggregation(grouped, :price_purchase, :spendings)
    assert_predicate totals.size, :positive?

    totals.each do |row|
      assert row[:currency]
      assert_not_nil row[:spendings]
    end
  ensure
    possession.reload.update!(price_purchase: nil, price_purchase_currency: nil)
  end

  test 'format_currency_with_presenters maps possessions to presenters and sorts by amount' do
    possession = possessions(:current_product)
    possession.update!(
      price_purchase: 50,
      price_purchase_currency: 'USD'
    )

    grouped = { 'USD' => [possession] }
    rows = StatisticsService.format_currency_with_presenters(grouped, :price_purchase)

    assert_equal 1, rows.size
    assert_equal 'USD', rows.first[:currency]
    assert_equal 1, rows.first[:possessions].size
    assert_kind_of PossessionPresenter, rows.first[:possessions].first
  ensure
    possession.reload.update!(price_purchase: nil, price_purchase_currency: nil)
  end

  test 'calculate top spending average returns neutral hash when nothing spent' do
    result = StatisticsService.calculate_top_spending_average(Possession.none, 3.0)

    assert_equal({ currency: 'n/a', spendings: 0 }, result)
  end

  test 'calculate top spending average divides leading currency total by year span' do
    possession = possessions(:current_product)
    possession.update!(
      price_purchase: 200,
      price_purchase_currency: 'EUR',
      period_from: Time.zone.local(2024, 3, 1)
    )

    avg = StatisticsService.calculate_top_spending_average(
      Possession.where(id: possession.id),
      2.0
    )

    assert_equal 'EUR', avg[:currency]
    assert_in_delta 100.0, avg[:spendings]
  ensure
    possession.reload.update!(
      price_purchase: nil,
      price_purchase_currency: nil,
      period_from: possessions(:current_product).period_from
    )
  end

  test 'calculate yearly averages returns ratio when dated possessions exist' do
    possession = possessions(:current_product)
    possession.update!(period_from: Time.zone.local(2024, 5, 1))

    travel_to(Time.zone.local(2026, 5, 3)) do
      result = StatisticsService.calculate_yearly_averages(Possession.where(id: possession.id))

      assert_operator result[:products], :>, 0
      assert result[:spendings].key?(:currency)
    end
  ensure
    possession.reload.update!(period_from: possessions(:current_product).period_from)
  end

  test 'yearly activity map buckets additions and removals by calendar year' do
    travel_to(Time.zone.local(2026, 6, 1)) do
      user = users(:without_anything)
      scope = Possession.where(user_id: user.id)
      scope.delete_all

      p_add = Possession.create!(
        user:,
        product: products(:one),
        period_from: Time.zone.local(2024, 6, 1),
        period_to: nil,
        prev_owned: false
      )
      p_remove = Possession.create!(
        user:,
        product: products(:two),
        period_from: Time.zone.local(2024, 1, 1),
        period_to: Time.zone.local(2025, 12, 31),
        prev_owned: false
      )

      map = StatisticsService.yearly_activity_map(scope)
      by_year = map.index_by { |row| row[:year] }

      assert_includes by_year[2024][:possessions][:from], p_add
      assert_includes by_year[2024][:possessions][:from], p_remove
      assert_includes by_year[2025][:possessions][:to], p_remove
    end
  end

  test 'yearly financial matrix merges spendings and earning rows per currency' do
    travel_to(Time.zone.local(2026, 6, 1)) do
      user = users(:without_anything)
      scope = Possession.where(user_id: user.id)
      scope.delete_all

      Possession.create!(
        user:,
        product: products(:one),
        period_from: Time.zone.local(2024, 3, 1),
        price_purchase: 100,
        price_purchase_currency: 'USD',
        prev_owned: false
      )
      Possession.create!(
        user:,
        product: products(:two),
        period_from: Time.zone.local(2023, 1, 1),
        period_to: Time.zone.local(2025, 6, 1),
        price_sale: 40,
        price_sale_currency: 'USD',
        prev_owned: true
      )

      matrix = StatisticsService.yearly_financial_matrix(scope)
      matching_year = 2024
      year_row = matrix.find { |r| r[:year] == matching_year }
      usd = year_row[:currencies].find { |c| c[:currency] == 'USD' }

      assert_equal 100, usd[:spendings]
      assert_equal 0, usd[:earnings]
    end
  end
end
