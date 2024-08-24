class PossessionPresenter < ItemPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::DateHelper

  def image_update_item
    @object
  end

  def delete_path
    possession_path(@object.id)
  end

  def update_path
    possession_path(@object.id)
  end

  def period_from
    @object.period_from
  end

  def period_to
    @object.period_to
  end

  def owned_for
    parsed_from = period_from.to_date if period_from.present?
    parsed_to = period_to.to_date if period_to.present?

    if prev_owned
      distance_of_time_in_words(parsed_to, parsed_from) if parsed_to && parsed_from
    elsif parsed_from
      distance_of_time_in_words(Time.zone.today, parsed_from)
    end
  end
end
