# frozen_string_literal: true

module EventsHelper
  def events_index_item_list_json_ld(events:, meta_desc:, active_events:, canonical_url: nil)
    list_url = canonical_url.presence || request.original_url

    schema_org_item_list(
      name: events_item_list_name(active_events:),
      url: list_url,
      description: meta_desc,
      item_list_order: events_item_list_order_url(active_events:),
      item_list_elements: events.each_with_index.map do |event, index|
        events_list_item(event, index, canonical_url: list_url)
      end
    )
  end

  private

  def events_item_list_name(active_events:)
    active_events == :upcoming ? 'Upcoming Hi-Fi Events & Shows' : 'Past Hi-Fi Events & Shows'
  end

  def events_item_list_order_url(active_events:)
    if active_events == :upcoming
      StructuredDataHelper::ITEM_LIST_ORDER_ASCENDING
    else
      StructuredDataHelper::ITEM_LIST_ORDER_DESCENDING
    end
  end

  def events_list_item(event, index, canonical_url:)
    {
      '@type' => 'ListItem',
      'position' => index + 1,
      'item' => events_schema_event(event, canonical_url:)
    }
  end

  def events_schema_event(event, canonical_url:)
    item = {
      '@type' => 'Event',
      'name' => event.name,
      'url' => events_url_for_schema(event, canonical_url:)
    }
    item['startDate'] = event.start_date.iso8601 if event.start_date
    item['endDate'] = event.end_date.iso8601 if event.end_date
    if event.address.present? || event.country_code.present?
      pa = { '@type' => 'PostalAddress' }
      pa['streetAddress'] = event.address if event.address.present?
      pa['addressCountry'] = event.country_code if event.country_code.present?
      item['location'] = { '@type' => 'Place', 'address' => pa }
    end
    item
  end

  def events_url_for_schema(event, canonical_url:)
    return event.url if event.url.present?

    "#{canonical_url}#event-#{event.id}"
  end
end
