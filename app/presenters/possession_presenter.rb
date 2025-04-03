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

  def sorted_images
    @object.images.sort_by { |image| @object.highlighted_image_id == image.id ? 0 : 1 }
  end

  def highlighted_image
    if @object.images.attached?
      return @object.images.find(@object.highlighted_image_id) if @object.highlighted_image_id

      return @object.images.first
    end

    nil
  end

  delegate :period_from, to: :@object

  delegate :period_to, to: :@object

  def owned_for
    return unless period_from.present? && period_to.present? && prev_owned

    parsed_from = period_from.to_date
    parsed_to = period_to.to_date

    distance_of_time_in_words(parsed_to, parsed_from)
  end
end
