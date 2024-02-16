module ApplicationHelper
  ABC = ('a'..'z').to_a.freeze

  def current_page?(test_path)
    request.path == test_path
  end

  def active_menu_state(active_menu, page)
    " aria-current=#{active_menu == page ? 'true' : 'false'}"
  end

  def active_dashboard_menu_state(active_dashboard_menu, page)
    " aria-current=#{active_dashboard_menu == page ? 'true' : 'false'}"
  end

  def abc
    ABC
  end

  def formatted_date(date)
    date.strftime('%Y-%m-%d')
  end

  def formatted_datetime(datetime)
    datetime.strftime('%Y-%m-%dT%H:%M')
  end

  def user_products_count(user)
    return unless user

    user.products.count
  end

  def user_bookmarks_count(user)
    return unless user

    user.bookmarks.count
  end

  def user_setups_count(user)
    return unless user

    user.setups.count
  end

  def user_prev_owneds_count(user)
    return unless user

    user.prev_owneds.count
  end

  def round_up_or_down(num)
    significant_digits = 2
    exp = Math.log10(num).floor - (significant_digits - 1)
    value = (num / 10.0**exp).round * 10**exp

    ceil = (num / 10.0**exp).ceil * 10**exp

    # rubocop:disable Style/ConditionalAssignment
    if num == value
      dir = :eq
    elsif value == ceil
      dir = :up
    else
      dir = :down
    end
    # rubocop:enable Style/ConditionalAssignment

    {
      value:,
      dir:,
    }
  end

  def user_has_product?(user, product)
    product && user && user.products.where(id: product.id).exists?
  end

  def user_has_bookmark?(user, product)
    product && user && user.bookmarks.where(product_id: product.id).exists?
  end

  def user_has_previously_owned?(user, product)
    product && user && user.prev_owneds.where(product_id: product.id).exists?
  end

  def user_has_brand?(user, brand)
    brand && user && user.products.where(brand_id: brand.id).exists?
  end

  def get_changelog(changes)
    PaperTrail::Serializers::YAML.load(changes)
  end

  def country_name(country_code)
    return nil if country_code.nil?

    country = ISO3166::Country[country_code]
    country.translations[I18n.locale.to_s] || country.common_name || country.iso_short_name
  end
end
