# frozen_string_literal: true

module UserActivityHelper
  include FormatHelper
  include UserActivityPeriodMeta

  def user_activity_product_link(item)
    link_to(h(item.display_name), item.url)
  end

  def user_activity_item_title(item)
    verb = item.verb&.to_sym
    if UserActivityVerbs.setup_product_verb?(verb)
      product_link = user_activity_product_link(item)
      setup_link =
        if item.setup_url.present?
          link_to(h(item.setup_name), item.setup_url)
        else
          h(item.setup_name)
        end
      return t(UserActivityVerbs.title_i18n_key(verb), product_link:, setup_link:).html_safe
    end

    link = user_activity_product_link(item)
    t(UserActivityVerbs.title_i18n_key(verb, event_past: item.event_past), link:).html_safe
  end

  def user_activity_gallery_images(items)
    collection =
      if items.respond_to?(:gallery_image)
        [items]
      else
        Array(items)
      end
    collection
      .filter_map(&:gallery_image)
      .sort_by { |image| image.created_at.to_f }
  end

  def feed_includes_possession_image_gallery?(feed_items)
    feed_items.any? do |row|
      verb = row.is_a?(UserActivityTimeline::Grouped) ? row.verb : row.item.verb
      verb == :possession_image_uploaded
    end
  end

  def user_activity_group_summary(group)
    sample = group.items.first
    verb = group.verb.to_sym
    key = UserActivityVerbs.grouped_summary_i18n_key(verb, event_past: sample.event_past)
    if verb == :possession_image_uploaded
      product_link = user_activity_product_link(sample)
      return t(key, count: group.items.size, product_link:).html_safe
    end
    if UserActivityVerbs.setup_product_verb?(verb)
      setup_link =
        if sample.setup_url.present?
          link_to(h(sample.setup_name), sample.setup_url)
        else
          h(sample.setup_name)
        end
      return t(key, count: group.items.size, setup_link:).html_safe
    end

    t(key, count: group.items.size).html_safe
  end

  def user_activity_icon(verb, event_upcoming: false)
    verb = verb&.to_sym
    return if verb.blank?
    return unless UserActivityVerbs.icon_verb?(verb)

    render partial: 'shared/activity/icon', locals: { verb:, event_upcoming: }
  end
end
