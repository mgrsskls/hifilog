module ApplicationHelper
  ABC = ('a'..'z').to_a.freeze
  STATUSES = %w[discontinued continued].freeze

  def current_page?(test_path)
    request.path == test_path
  end

  def active_menu_state(active_menu, page)
    " aria-current=#{active_menu == page ? 'true' : 'false'}"
  end

  def abc
    ABC
  end

  def statuses
    STATUSES
  end

  def user_possessions_count(user)
    return unless user

    user.possessions.where(prev_owned: false).count
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

    user.custom_products.count
  end

  def user_prev_owneds_count(user)
    return unless user

    user.possessions.where(prev_owned: true).count
  end

  def user_notes_count(user)
    return unless user

    user.notes.count
  end

  def round_up_or_down(num)
    significant_digits = 2
    exp = Math.log10(num).floor - (significant_digits - 1)
    value = (num / (10.0**exp)).round * (10**exp)

    ceil = (num / (10.0**exp)).ceil * (10**exp)

    dir = if num == value
            :eq
          elsif value == ceil
            :up
          else
            :down
          end

    {
      value:,
      dir:,
    }
  end

  def user_has_product?(user, product_id, product_variant_id = nil)
    return false unless user

    user.possessions.exists?(product_id:, product_variant_id:, prev_owned: false)
  end

  def user_has_bookmark?(user, product, variant_id = nil)
    product && user && user.bookmarks.exists?(product_id: product.id, product_variant_id: variant_id)
  end

  def user_has_previously_owned?(user, product, variant_id = nil)
    product && user && user.possessions.exists?(
      product_id: product.id,
      product_variant_id: variant_id,
      prev_owned: true
    )
  end

  def user_has_brand?(user, brand, prev_owned)
    return false unless brand && user

    user.possessions
        .where(prev_owned:)
        .joins(:product)
        .where({ product: { brand_id: brand.id } })
        .any?
  end

  def get_changelog(changes)
    PaperTrail::Serializers::YAML.load(changes)
  end

  def country_name_from_country_code(country_code)
    return nil if country_code.nil?

    country = ISO3166::Country[country_code]

    return if country.nil?

    country.translations[I18n.locale.to_s] || country.common_name || country.iso_short_name
  end
end
