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
    date.strftime('%Y-%m-%dT00:00+0000')
  end

  def formatted_datetime(datetime)
    datetime.strftime('%Y-%m-%dT%H:%M+0000')
  end

  def user_possessions_count(user)
    return unless user

    user.possessions.count
  end

  def user_bookmarks_count(user)
    return unless user

    user.bookmarks.count
  end

  def user_setups_count(user)
    return unless user

    user.setups.count
  end

  def user_custom_products_count(user)
    return unless user

    user.possessions.where.not(custom_product_id: nil).count
  end

  def user_prev_owneds_count(user)
    return unless user

    user.prev_owneds.count
  end

  def user_notes_count(user)
    return unless user

    user.notes.count
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

  def user_has_product?(user, product_id, product_variant_id = nil)
    user && user.possessions.where(product_id:, product_variant_id:).exists?
  end

  def user_has_bookmark?(user, product, variant_id = nil)
    product && user && user.bookmarks.where(product_id: product.id, product_variant_id: variant_id).exists?
  end

  def user_has_previously_owned?(user, product, variant_id = nil)
    product && user && user.prev_owneds.where(product_id: product.id, product_variant_id: variant_id).exists?
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

    return if country.nil?

    country.translations[I18n.locale.to_s] || country.common_name || country.iso_short_name
  end

  def custom_attributes_list(product)
    return unless product.custom_attributes.present? && product.custom_attributes.any?

    attributes = []

    product.custom_attributes.each do |custom_attribute|
      custom_attribute_resource = CustomAttribute.find(custom_attribute[0])
      attributes.push I18n.t("custom_attributes.#{custom_attribute_resource.options[custom_attribute[1].to_s]}")
    end

    attributes.join(', ') if attributes.any?
  end
end
