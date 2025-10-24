# rubocop:disable Metrics/ModuleLength
module ApplicationHelper
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper
  include FilterConstants

  def current_page?(test_path)
    request.path == test_path
  end

  def active_menu_state(active_menu, page)
    " aria-current=#{active_menu == page ? 'true' : 'false'}"
  end

  def statuses
    STATUSES
  end

  def display_price(price, currency)
    "#{number_with_delimiter number_to_rounded(price, precision: 2)} #{currency}"
  end

  def user_possessions_count(user:, prev_owned: false)
    return unless user

    user.possessions.select { |p| p.prev_owned == prev_owned }.length
  end

  def user_bookmarks_count(user)
    return unless user

    user.bookmarks.count
  end

  def user_events_count(user)
    return unless user

    user.event_attendees.count
  end

  def user_setups_count(user)
    return unless user

    user.setups.count
  end

  def user_custom_products_count(user)
    return unless user

    user.custom_products.count
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
    product && user&.bookmarks&.exists?(product_id: product.id, product_variant_id: variant_id)
  end

  def user_has_previously_owned?(user, product, variant_id = nil)
    product && user&.possessions&.exists?(
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

  def get_products_per_brand(possessions:)
    products_per_brand = possessions.map do |possession|
      if possession.custom_product
        {
          brand_name: CustomProductPresenter.new(possession.custom_product).brand_name,
          possession:
        }
      else
        {
          brand_name: possession.product.brand.name,
          possession:
        }
      end
    end

    products_per_brand = products_per_brand.group_by do |possession|
      possession[:brand_name]
    end

    products_per_brand.sort_by do |brand|
      [-brand[1].size, brand[0].downcase]
    end
  end

  def hidden_fields_for_params(params_hash, prefix: nil, skip_blank: true)
    # If it's ActionController::Parameters, convert to a plain hash for iteration.
    params_hash = params_hash.to_unsafe_h if params_hash.respond_to?(:to_unsafe_h)

    tags = []

    params_hash.each do |key, value|
      next if key.in?([:controller, :action]) # safety

      name = prefix ? "#{prefix}[#{key}]" : key.to_s

      case value
      when ActionController::Parameters, Hash
        tags << hidden_fields_for_params(value, prefix: name, skip_blank: skip_blank)
      when Array
        value.each do |v|
          if v.is_a?(ActionController::Parameters) || v.is_a?(Hash)
            # array of hashes -> use name[] as prefix for each nested hash
            tags << hidden_fields_for_params(v, prefix: "#{name}[]", skip_blank: skip_blank)
          else
            next if skip_blank && v.blank?

            tags << hidden_field_tag("#{name}[]", v)
          end
        end
      else
        next if skip_blank && value.blank?

        tags << hidden_field_tag(name, value)
      end
    end

    safe_join(tags)
  end
end
# rubocop:enable Metrics/ModuleLength
