# frozen_string_literal: true

# Finds and ranks the products that are most similar to one product. The weights are in
# SimilarProducts::Weights. See README, section "Similar Products".
#
# The query does all the scoring in the database and sends back only the top rows. It does not
# load candidates into Ruby.
#
# Candidates are only products that have at least one sub category in common with the product.
# The index on products_sub_categories.sub_category_id finds them. Thus, the number of rows
# that the query must score is the size of the sub categories of the product, not the size of
# the catalogue.
#
# The values of the product are known before the query starts. Thus, the query contains them as
# constants, and it has one term for each attribute that the product has. An attribute that the
# product does not have does not make the query longer.
#
# `@>` is used, and not `?`: `?` is the bind placeholder of Rails.
class SimilarProducts::Query
  include SimilaritySql

  W = SimilarProducts::Weights

  NUMBER_PATTERN = '^-?[0-9]+(\.[0-9]+)?$'
  ORDER = 'scored.exact_match DESC, scored.score DESC, scored.status_match DESC, ' \
          'scored.year_distance ASC NULLS LAST, scored.id ASC'

  # ids:         the ProductItem ids (uuid strings) of the requested rows, best first
  # total_count: the number of all candidates with the minimum score
  Result = Struct.new(:ids, :total_count, keyword_init: true)
  EMPTY = Result.new(ids: [], total_count: 0).freeze

  def initialize(product:, sub_category_ids:, limit:, offset: 0)
    @product = product
    @sub_category_ids = sub_category_ids.map(&:to_i).uniq
    @limit = limit.to_i
    @offset = [offset.to_i, 0].max
  end

  def call
    return EMPTY if @sub_category_ids.empty? || @limit <= 0

    row = ActiveRecord::Base.connection.exec_query(sql).first
    Result.new(ids: row['ids'].to_s.split(','), total_count: row['total_count'].to_i)
  end

  private

  # Steps:
  #   shared: the candidates, with the number of sub categories they share with the product
  #   scored: the score and the tiebreakers of each candidate. `totals` is the number of all sub
  #           categories of the candidate. The index on (product_id, sub_category_id) gives it
  #           without a read of the table.
  #   ranked: the candidates with the minimum score
  #   top:    the requested rows (one page)
  # The statement always returns one row, also for a page after the last one. Thus, the total
  # is known in all cases. `ranked` is used two times, so PostgreSQL calculates it one time and
  # keeps the result.
  # The uuid is calculated only for the rows in `top`. For all candidates, it is too slow. The
  # ids are sent as one comma-separated text: a uuid contains no comma.
  def sql
    <<~SQL.squish
      WITH shared AS (
        SELECT psc.product_id, count(*) AS shared_count
        FROM products_sub_categories psc
        WHERE psc.sub_category_id = ANY(#{id_array(@sub_category_ids)})
          AND psc.product_id <> #{@product.id.to_i}
        GROUP BY psc.product_id
      ),
      scored AS (
        SELECT p.id,
               (totals.total_count = shared.shared_count
                 AND shared.shared_count = #{@sub_category_ids.size}) AS exact_match,
               (#{sub_category_term} + attributes.points#{numeric_terms.map { |term| " + #{term}" }.join}
                 + #{price_term}) AS score,
               #{status_tiebreaker} AS status_match,
               #{year_tiebreaker} AS year_distance
        FROM shared
        JOIN products p ON p.id = shared.product_id
        JOIN LATERAL (
          SELECT count(*) AS total_count
          FROM products_sub_categories all_psc
          WHERE all_psc.product_id = p.id
        ) totals ON TRUE
        CROSS JOIN LATERAL (#{categorical_sql}) attributes
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
             (SELECT string_agg(uuid_generate_v5(uuid_ns_dns(), 'product-' || scored.id::text)::text, ','
                                ORDER BY #{ORDER})
              FROM top scored) AS ids
    SQL
  end

  # ------------------------------------------------------------------------------ Sub categories

  # Jaccard index: shared / (all sub categories of the product and the candidate together).
  def sub_category_term
    "(#{W::SUB_CATEGORY_WEIGHT}::float8 * shared.shared_count / " \
      "(#{@sub_category_ids.size} + totals.total_count - shared.shared_count))"
  end

  # ------------------------------------------------------------------------------ Attributes

  def source_attributes
    @source_attributes ||= @product.custom_attributes.is_a?(Hash) ? @product.custom_attributes : {}
  end

  # For option, options and boolean attributes. Both sides are made into a JSON array: an
  # option attribute keeps one value, an options attribute keeps an array. Then the points are
  # weight * shared / (all values of both).
  #
  # Three levels, so that the database calculates each array and each count one time per row:
  #   1. `arrays`:  the candidate value of each attribute as an array
  #   2. `matches`: the number of values that the candidate and the product have in common
  #   3. the points
  # `OFFSET 0` prevents that PostgreSQL merges the levels into one expression. If it merges
  # them, it copies the array expression into each place that uses it and calculates it again.
  def categorical_sql
    attributes = categorical_attributes
    return 'SELECT 0::float8 AS points' if attributes.empty?

    arrays = attributes.each_with_index.map { |(label, _, _), index| "#{candidate_array(label)} AS a#{index}" }
    matches = attributes.each_with_index.map do |(_, _, values), index|
      shared = values.map { |value| "(a#{index} @> #{quote([value].to_json)}::jsonb)::int" }.join(' + ')
      "a#{index}, (#{shared}) AS m#{index}"
    end
    points = attributes.each_with_index.map do |(_, weight, values), index|
      union = "#{values.size} + jsonb_array_length(a#{index}) - m#{index}"
      "COALESCE(#{weight}::float8 * m#{index} / NULLIF(#{union}, 0), 0)"
    end

    "SELECT #{points.join(' + ')} AS points FROM (SELECT #{matches.join(', ')} " \
      "FROM (SELECT #{arrays.join(', ')} OFFSET 0) arrays OFFSET 0) matches"
  end

  # [label, weight, values] for each weighted attribute that the product has a value for.
  def categorical_attributes
    W::ATTRIBUTES.filter_map do |label, weight|
      values = categorical_values(source_attributes[label])
      [label, weight, values] if values.any?
    end
  end

  def candidate_array(label)
    json_array_sql("p.custom_attributes -> #{quote(label)}")
  end

  # Full points when the values of both sides are in the same class. When the product has a
  # unit, the candidate must have the same unit. Units are kept in their canonical form (see
  # CustomAttribute::UNIT_CONVERSIONS), so a text comparison is sufficient.
  def numeric_terms
    W::NUMERIC_CLASSES.filter_map do |label, config|
      source = numeric_source(label, config)
      next if source.nil?

      value_text = candidate_number_text(label, config[:input])
      value = "(CASE WHEN #{value_text} ~ #{quote(NUMBER_PATTERN)} THEN (#{value_text})::numeric END)"
      limits = "ARRAY[#{config[:limits].join(', ')}]::numeric[]"

      "(CASE WHEN width_bucket(#{value}, #{limits}) = #{source[:bucket]}#{unit_sql(label, source[:unit])} " \
        "THEN #{config[:weight]} ELSE 0 END)"
    end
  end

  def unit_sql(label, unit)
    return '' if unit.nil?

    " AND p.custom_attributes -> #{quote(label)} ->> 'unit' = #{quote(unit)}"
  end

  def numeric_source(label, config)
    entry = source_attributes[label]
    return nil unless entry.is_a?(Hash)

    raw = entry['value']
    # An attribute with inputs keeps a value for each input: { "ohm_8" => 50, "ohm_4" => 80 }.
    if config[:input]
      raw = raw.is_a?(Hash) ? raw[config[:input]] : nil
    end
    number = Float(raw.to_s, exception: false)
    return nil if number.nil?

    { bucket: config[:limits].count { |limit| number >= limit }, unit: entry['unit'].presence }
  end

  def candidate_number_text(label, input)
    return "(p.custom_attributes -> #{quote(label)} -> 'value' ->> #{quote(input)})" if input

    "(p.custom_attributes -> #{quote(label)} ->> 'value')"
  end

  # ------------------------------------------------------------------------------ Price

  def price_term
    price_band_sql(columns: { price: 'p.price', currency: 'p.price_currency' },
                   price: @product.price, currency: @product.price_currency,
                   weight: W::PRICE_WEIGHT, width: W::PRICE_BAND_WIDTH)
  end

  # ------------------------------------------------------------------------------ Tiebreakers

  def status_tiebreaker
    "(p.discontinued = #{@product.discontinued ? 'TRUE' : 'FALSE'})::int"
  end

  def year_tiebreaker
    return 'NULL::int' if @product.release_year.nil?

    "abs(p.release_year - #{@product.release_year.to_i})"
  end
end
