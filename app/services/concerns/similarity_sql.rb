# frozen_string_literal: true

# SQL parts that SimilarProducts::Query and SimilarBrands::Query both use. See README, sections
# "Similar Products" and "Similar Brands".
#
# All methods return SQL text. Values of the source record are put into the SQL as quoted
# constants, so the statement needs no bind parameters.
module SimilaritySql
  private

  # A custom attribute value as a JSON array. An option attribute keeps one value, an options
  # attribute keeps an array, a boolean attribute keeps true or false. A missing value or a value
  # of another type gives an empty array.
  #
  # `value` is a jsonb expression, for example "p.custom_attributes -> 'amplifier_type'".
  def json_array_sql(value)
    "(CASE WHEN jsonb_typeof(#{value}) = 'array' THEN #{value} " \
      "WHEN jsonb_typeof(#{value}) IN ('string', 'boolean') THEN jsonb_build_array(#{value}) " \
      "ELSE '[]'::jsonb END)"
  end

  # The values of a categorical attribute of the source, as a Ruby array: strings and booleans
  # only, no empty strings, no duplicates.
  def categorical_values(value)
    values = Array.wrap(value).select { |item| item.is_a?(String) || item == true || item == false }
    values.reject { |item| item == '' }.uniq
  end

  # Log-scale price bands, only in the same currency. Prices of different currencies and eras are
  # not converted: the result would not be more correct than no comparison.
  #
  # Full `weight` for the same band, half of it for the next band, else 0. Returns '0' when the
  # source has no price.
  #
  # The band limits are calculated here, so the database only compares numbers. `log()` on a
  # numeric column is slow when it runs for each candidate.
  def price_band_sql(columns:, price:, currency:, weight:, width:)
    price_column, currency_column = columns.values_at(:price, :currency)
    band = price_band(price, width)
    currency = currency.presence
    return '0' if band.nil? || currency.nil?

    same = "#{price_column} >= #{band_limit(band, width)} AND #{price_column} < #{band_limit(band + 1, width)}"
    near = "#{price_column} >= #{band_limit(band - 1, width)} AND #{price_column} < #{band_limit(band + 2, width)}"
    "(CASE WHEN #{currency_column} IS DISTINCT FROM #{quote(currency)} THEN 0 " \
      "WHEN #{same} THEN #{weight} WHEN #{near} THEN #{weight / 2.0} ELSE 0 END)"
  end

  def price_band(price, width)
    return nil if price.nil? || price <= 0

    (Math.log10(price.to_f) / width).floor
  end

  def band_limit(band, width)
    (10**(band * width)).round(4)
  end

  def id_array(ids)
    "ARRAY[#{ids.map(&:to_i).join(', ')}]::bigint[]"
  end

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
