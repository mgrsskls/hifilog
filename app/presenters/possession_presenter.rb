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
    return unless period_from.present? && period_to.present? && prev_owned

    parsed_from = period_from.to_date
    parsed_to = period_to.to_date

    distance_of_time_in_words(parsed_to, parsed_from)
  end
end
