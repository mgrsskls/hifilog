# frozen_string_literal: true

# Everything the logged-out home page shows of the live database: what was added last, which
# photos came in with it, what is coming up, what was edited, and how far the catalogue has got.
#
# It is one service rather than six controller queries because this is the most requested page of
# the site and every block here has the same two constraints: it must not order a large table on
# an unindexed column, and it must render nothing rather than something empty when the database
# has no rows for it yet.
#
# Everything is read-only. The blocks return plain structs, so the partials need no model
# knowledge and a change to a model cannot silently change the markup.
class HomeHighlights
  Entry = Struct.new(:kind, :title, :subtitle, :meta, :detail, :path, :image, :image_kind,
                     :created_at, keyword_init: true)

  JUST_ADDED_LIMIT = 5
  PHOTOS_LIMIT = 7
  EVENTS_LIMIT = 4
  PULSE_PERIOD = 7.days
  EDITABLE_TYPES = %w[Brand Product ProductVariant].freeze

  class << self
    # Products, variants and brands in one stream, newest first.
    def just_added(limit: JUST_ADDED_LIMIT)
      (product_entries(limit) + brand_entries(limit))
        .sort_by { |entry| entry.created_at || Time.zone.at(0) }
        .reverse
        .first(limit)
    end

    # Photos from public collections. Ordered by when the gear was logged rather than by when the
    # file was attached: the attachment table has no index for that order and the two barely
    # differ in practice.
    def photos(limit: PHOTOS_LIMIT)
      possessions = Possession.recent_preview(limit)
                              .joins(:user)
                              .merge(User.publicly_indexable)
                              .where(custom_product_id: nil)

      PossessionPresenterService.map_to_presenters(possessions.to_a).filter_map do |presenter|
        image = presenter.highlighted_image
        next unless image

        Photo.new(
          image: image,
          title: presenter.display_name,
          path: presenter.show_path,
          user_name: presenter.object.user.user_name
        )
      end
    end

    # Upcoming, not newest: a fair next month is worth more here than one entered last night.
    # Attendee counts come from one grouped query, not one per card.
    def upcoming_events(limit: EVENTS_LIMIT)
      events = Event.upcoming.order(:start_date).limit(limit).to_a
      return [events, {}] if events.empty?

      [events, EventAttendee.where(event_id: events.map(&:id)).group(:event_id).count]
    end

    # Totals for the closing band. The first three are the same cached values the intro uses.
    def totals
      Rails.cache.fetch('/home/totals', expires_in: 6.hours) do
        {
          products: CacheService.products_count,
          brands: CacheService.brands_count,
          categories: CacheService.categories_count,
          users: CacheService.users_count,
          events: CacheService.events_count
        }
      end
    end

    private

    def possession_images
      ActiveStorage::Attachment.where(record_type: 'Possession', name: 'images')
    end

    # product_items is a view over products and product_variants, so it is read by the identifiers
    # CacheService keeps and never ordered by created_at (see
    # CacheService.newest_product_item_refs).
    def product_entries(limit)
      relation = product_item_relation(CacheService.newest_product_item_refs.first(limit))
      return [] unless relation

      relation = ProductItem.preload_list_possession_images(relation)
      relation = ProductItem.preload_sub_category_names(relation)

      relation.map do |item|
        presenter = ProductItemPresenter.new(item, false)

        Entry.new(
          kind: :product,
          title: presenter.display_name,
          subtitle: presenter.brand_name,
          meta: presenter.sub_category_names.first,
          detail: item.release_year,
          path: presenter.path,
          image: presenter.list_highlighted_image,
          image_kind: :photo,
          created_at: item.created_at
        )
      end
    end

    def product_item_relation(refs)
      product_ids = refs.select { |p| p.first == 'Product' }.map(&:last)
      variant_ids = refs.select { |p| p.first == 'ProductVariant' }.map(&:last)

      scopes = []
      scopes << ProductItem.where(item_type: 'Product', product_id: product_ids) if product_ids.any?
      scopes << ProductItem.where(item_type: 'ProductVariant', product_variant_id: variant_ids) if variant_ids.any?
      return nil if scopes.empty?

      scopes.reduce(:or).includes(:brand).order(created_at: :desc)
    end

    def brand_entries(limit)
      Brand.with_attached_logo.order(created_at: :desc).limit(limit).map do |brand|
        count = brand.products_count.to_i

        Entry.new(
          kind: :brand,
          title: brand.display_name,
          subtitle: Brand.model_name.human,
          meta: brand.country_name,
          detail: ("#{count} #{I18n.t('activerecord.models.product', count: count)}" if count.positive?),
          path: routes.brand_path(id: brand.friendly_id),
          image: (brand.logo if brand.logo.attached?),
          image_kind: :logo,
          created_at: brand.created_at
        )
      end
    end

    def editable_items(versions)
      versions.group_by(&:item_type).each_with_object({}) do |(type, rows), memo|
        ids = rows.map(&:item_id).uniq
        records = case type
                  when 'Brand' then Brand.where(id: ids)
                  when 'Product' then Product.includes(:brand).where(id: ids)
                  else ProductVariant.includes(product: :brand).where(id: ids)
                  end

        records.each { |record| memo[[type, record.id]] = record }
      end
    end

    # whodunnit holds a user id as a string, and the account may be gone. A hidden profile is
    # named but not linked, the same rule the changelog applies.
    def edit_actors(versions)
      ids = versions.filter_map(&:whodunnit).uniq
      return {} if ids.empty?

      User.where(id: ids).index_by { |user| user.id.to_s }
    end

    def edit_for(version, items, actors)
      return nil if version.created_at.blank?

      record = items[[version.item_type, version.item_id]]
      return nil unless record

      actor = actors[version.whodunnit]

      Edit.new(
        actor: actor&.user_name,
        actor_path: (actor.profile_path unless actor.nil? || actor.hidden?),
        event: version.event,
        title: record.display_name,
        path: record.is_a?(Brand) ? routes.brand_path(id: record.friendly_id) : record.path,
        at: version.created_at
      )
    end

    def routes
      Rails.application.routes.url_helpers
    end
  end
end
