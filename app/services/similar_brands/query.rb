# frozen_string_literal: true

# Finds and ranks the brands that are most similar to one brand. The weights are in
# SimilarBrands::Weights. See README, section "Similar Brands".
#
# Two steps:
#
#   1. Ruby reads the profile of the brand from its own products: the share of its products in
#      each sub category, the most frequent value of each weighted attribute, and the median price
#      in its most frequent currency.
#   2. One SQL statement makes the same profile for all candidate brands, calculates the scores
#      and sends back only the ids of the requested rows and the number of all candidates.
#
# Candidates are brands with at least one product in a sub category of the brand. Their profile
# uses only these products: a turntable maker is compared on turntables, also when the candidate
# makes amplifiers too. The share of a candidate is divided by all its products (counted directly,
# not read from `brands.products_count`, because that column also counts variants), so a candidate
# that makes mostly other things gets a small share.
#
# The index on products_sub_categories.sub_category_id finds the products. The work depends on the
# number of products in the sub categories of the brand, not on the size of the catalogue. For a
# brand in many sub categories that is a large part of the catalogue, which is why the result is
# cached (SimilarBrands).
class SimilarBrands::Query
  include SimilaritySql

  W = SimilarBrands::Weights

  ORDER = 'scored.score DESC, scored.status_match DESC, scored.products_count DESC, scored.id ASC'

  # ids:         the brand ids of the requested rows, best first
  # total_count: the number of all candidates with the minimum score
  Result = Struct.new(:ids, :total_count, keyword_init: true)
  EMPTY = Result.new(ids: [], total_count: 0).freeze

  def initialize(brand:, limit:, offset: 0)
    @brand = brand
    @limit = limit.to_i
    @offset = [offset.to_i, 0].max
  end

  def call
    return EMPTY if shares.empty? || @limit <= 0

    row = ActiveRecord::Base.connection.exec_query(sql).first
    Result.new(ids: row['ids'].to_s.split(',').map(&:to_i), total_count: row['total_count'].to_i)
  end

  private

  # Steps:
  #   source_shares:    the share of the brand's products in each of its sub categories (constants)
  #   per_sub_category: the number of products of each candidate brand in each of these sub
  #                     categories
  #   profiles:         the sub category overlap of each candidate brand
  #   aggregates:       the attribute shares and the median price of each candidate brand, from
  #                     its products in these sub categories (each product one time)
  #   scored, ranked, top: as in SimilarProducts::Query
  # per_sub_category and aggregates read the products separately. A shared CTE would be
  # materialized, and PostgreSQL then estimates its size badly and sorts on disk.
  # The statement always returns one row, also for a page after the last one.
  def sql
    <<~SQL.squish
      WITH source_shares (sub_category_id, share) AS (
        VALUES #{shares.map { |id, share| "(#{id.to_i}::bigint, #{share.to_f}::float8)" }.join(', ')}
      ),
      per_sub_category AS (
        SELECT p.brand_id, psc.sub_category_id, count(*) AS product_count
        FROM products_sub_categories psc
        JOIN products p ON p.id = psc.product_id
        WHERE psc.sub_category_id = ANY(#{id_array(shares.keys)})
          AND p.brand_id <> #{@brand.id.to_i}
        GROUP BY p.brand_id, psc.sub_category_id
      ),
      candidate_product_counts AS (
        SELECT p.brand_id, count(*) AS product_count
        FROM products p
        WHERE p.brand_id IN (SELECT DISTINCT brand_id FROM per_sub_category)
        GROUP BY p.brand_id
      ),
      profiles AS (
        SELECT psc.brand_id,
               LEAST(1, sum(LEAST(psc.product_count::float8 / NULLIF(cpc.product_count, 0), ss.share))) AS overlap
        FROM per_sub_category psc
        JOIN candidate_product_counts cpc ON cpc.brand_id = psc.brand_id
        JOIN source_shares ss ON ss.sub_category_id = psc.sub_category_id
        GROUP BY psc.brand_id
      ),
      aggregates AS (#{aggregates_sql}),
      scored AS (
        SELECT b.id, b.products_count,
               (#{W::SUB_CATEGORY_WEIGHT}::float8 * COALESCE(profiles.overlap, 0)
                 + #{period_term} + #{country_term} + #{price_term} + #{attribute_term}) AS score,
               (COALESCE(b.discontinued, FALSE) = #{@brand.discontinued ? 'TRUE' : 'FALSE'})::int AS status_match
        FROM profiles
        JOIN brands b ON b.id = profiles.brand_id
        LEFT JOIN aggregates ON aggregates.brand_id = b.id
        OFFSET 0
      ),
      ranked AS (
        SELECT * FROM scored WHERE scored.score >= #{W::MIN_SCORE}
      ),
      top AS (
        SELECT * FROM ranked scored
        ORDER BY #{ORDER}
        LIMIT #{@limit} OFFSET #{@offset}
      )
      SELECT (SELECT count(*) FROM ranked) AS total_count,
             (SELECT string_agg(scored.id::text, ',' ORDER BY #{ORDER}) FROM top scored) AS ids
    SQL
  end

  # ------------------------------------------------------------------------------ Source profile

  # { sub_category_id => share }. A product in two sub categories counts in both, so the shares
  # can add up to more than 1. The overlap is capped at 1 in the SQL.
  def shares
    @shares ||= source_shares
  end

  def source_shares
    total = source_products.size
    return {} if total.zero?

    counts = ActiveRecord::Base.connection.select_rows(<<~SQL.squish)
      SELECT psc.sub_category_id, count(*)
      FROM products_sub_categories psc
      JOIN products p ON p.id = psc.product_id
      WHERE p.brand_id = #{@brand.id.to_i}
      GROUP BY psc.sub_category_id
    SQL
    counts.to_h { |id, count| [id.to_i, [count.to_f / total, 1.0].min] }
  end

  # [custom_attributes, price, price_currency] of each product of the brand.
  def source_products
    @source_products ||= Product.where(brand_id: @brand.id).pluck(:custom_attributes, :price, :price_currency)
  end

  # [label, weight, value] for each weighted attribute: the most frequent value among the
  # products of the brand. A tie is decided by the value, so that the result is always the same.
  def dominant_values
    @dominant_values ||= W::ATTRIBUTES.filter_map do |label, weight|
      values = source_products.flat_map do |attributes, _, _|
        categorical_values(attributes.is_a?(Hash) ? attributes[label] : nil)
      end
      next if values.empty?

      value, = values.tally.max_by { |candidate, count| [count, candidate.to_s] }
      [label, weight, value]
    end
  end

  # [currency, median price] in the most frequent currency of the priced products, or nil.
  def source_price
    return @source_price if defined?(@source_price)

    @source_price = median_price_in_main_currency
  end

  def median_price_in_main_currency
    priced = source_products.filter_map { |_, price, currency| [currency, price] if price&.positive? && currency }
    return nil if priced.empty?

    currency, = priced.map(&:first).tally.max_by { |candidate, count| [count, candidate] }
    prices = priced.filter_map { |c, price| price if c == currency }.sort
    middle = prices.size / 2
    median = prices.size.odd? ? prices[middle] : (prices[middle - 1] + prices[middle]) / 2
    [currency, median]
  end

  # ------------------------------------------------------------------------------ Aggregates

  # One row for each candidate brand. `a0`, `a1`, ... are the candidate arrays of the attributes,
  # calculated one time per product (`OFFSET 0`, see SimilarProducts::Query#categorical_sql).
  def aggregates_sql
    columns = ['cp.brand_id']
    columns += dominant_values.each_with_index.map do |(_, _, value), index|
      "count(*) FILTER (WHERE arrays.a#{index} @> #{quote([value].to_json)}::jsonb)::float8 / " \
        "NULLIF(count(*) FILTER (WHERE jsonb_array_length(arrays.a#{index}) > 0), 0) AS s#{index}"
    end
    columns << median_price_sql

    arrays = dominant_values.each_with_index.map do |(label, _, _), index|
      "#{json_array_sql("cp.custom_attributes -> #{quote(label)}")} AS a#{index}"
    end
    arrays = ['NULL AS unused'] if arrays.empty?

    "SELECT #{columns.join(', ')} FROM products cp " \
      "CROSS JOIN LATERAL (SELECT #{arrays.join(', ')} OFFSET 0) arrays " \
      "WHERE cp.brand_id <> #{@brand.id.to_i} AND cp.id IN (SELECT psc.product_id FROM products_sub_categories psc " \
      "WHERE psc.sub_category_id = ANY(#{id_array(shares.keys)})) GROUP BY cp.brand_id"
  end

  def median_price_sql
    return 'NULL::numeric AS median_price' if source_price.nil?

    'percentile_cont(0.5) WITHIN GROUP (ORDER BY cp.price) FILTER ' \
      "(WHERE cp.price_currency = #{quote(source_price.first)} AND cp.price > 0) AS median_price"
  end

  # ------------------------------------------------------------------------------ Terms

  def attribute_term
    return '0' if dominant_values.empty?

    dominant_values.each_with_index.map do |(_, weight, _), index|
      "COALESCE(#{weight}::float8 * aggregates.s#{index}, 0)"
    end.join(' + ')
  end

  def price_term
    return '0' if source_price.nil?

    # The median is already in the source currency, so the currency always matches.
    price_band_sql(columns: { price: 'aggregates.median_price', currency: quote(source_price.first) },
                   price: source_price.last, currency: source_price.first,
                   weight: W::PRICE_WEIGHT, width: W::PRICE_BAND_WIDTH)
  end

  def country_term
    return '0' if @brand.country_code.blank?

    "(CASE WHEN b.country_code = #{quote(@brand.country_code)} THEN #{W::COUNTRY_WEIGHT} ELSE 0 END)"
  end

  # Shared years / all years of both active periods (Jaccard index of two intervals). A brand is
  # active from its founded year to its discontinued year, or to this year when it is still in
  # business. An unknown start or end gives 0 points.
  def period_term
    start, finish = period(@brand.founded_year, @brand.discontinued, @brand.discontinued_year)
    return '0' if start.nil?

    candidate_end = "(CASE WHEN b.discontinued THEN b.discontinued_year ELSE #{current_year} END)"
    shared = "GREATEST(0, LEAST(#{finish}, #{candidate_end}) - GREATEST(#{start}, b.founded_year) + 1)"
    all = "(GREATEST(#{finish}, #{candidate_end}) - LEAST(#{start}, b.founded_year) + 1)"

    "(CASE WHEN b.founded_year IS NULL OR #{candidate_end} IS NULL OR #{candidate_end} < b.founded_year " \
      "THEN 0 ELSE #{W::PERIOD_WEIGHT}::float8 * #{shared} / #{all} END)"
  end

  def period(founded_year, discontinued, discontinued_year)
    finish = discontinued ? discontinued_year : current_year
    return [nil, nil] if founded_year.nil? || finish.nil? || finish < founded_year

    [founded_year.to_i, finish.to_i]
  end

  def current_year
    Date.current.year
  end
end
