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

  def user_activity_group_summary(group)
    sample = group.items.first
    verb = group.verb.to_sym
    key = UserActivityVerbs.grouped_summary_i18n_key(verb, event_past: sample.event_past)
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
