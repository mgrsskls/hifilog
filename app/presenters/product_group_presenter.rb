class ProductGroupPresenter
  delegate_missing_to :@product

  def initialize(object)
    @product = object
    @variants = @product.product_variants
  end

  def continued?
    return true unless @product.discontinued?
    return true unless @variants.all?(&:discontinued?)

    false
  end

  def prices
    [[@product.price, @product.price_currency], *@variants.map { |v| [v.price, v.price_currency] }]
      .reject { |p| p[0].nil? }
  end

  def lowest_price
    prices.min_by { |price| price[0] }
  end

  def release_dates
    [
      [@product.release_year, @product.release_month, @product.release_day], *@variants.map do |v|
        [v.release_year, v.release_month, v.release_day]
      end
    ]
      .reject { |p| p[0].nil? }
      .sort_by { |p| p.map { |e| e.nil? ? 0 : e } }
  end

  def earliest_release_date
    release_dates.first
  end

  def discontinued_dates
    [
      [@product.discontinued_year, @product.discontinued_month, @product.discontinued_day], *@variants.map do |v|
        [v.discontinued_year, v.discontinued_month, v.discontinued_day]
      end
    ]
      .reject { |p| p[0].nil? }
  end

  def latest_discontinued_date
    discontinued_dates.max
  end

  def path
    return product_path(id: @product.friendly_id) if @variants.none?

    # todo
    product_path(id: @product.friendly_id)
  end
end
