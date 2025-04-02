class CustomProductPossessionPresenter < CustomProductPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::DateHelper

  delegate_missing_to :@object

  def initialize(object)
    super

    @object = object
    @custom_product = object.custom_product
  end

  delegate :images, to: :@custom_product

  def image_update_item
    @custom_product
  end

  def delete_path
    possession_path(@object.id)
  end

  def delete_button_label
    I18n.t('product.remove_from_prev_owneds.label')
  end

  def delete_confirm_msg
    I18n.t('product.remove_from_prev_owneds.confirm', name: display_name)
  end

  delegate :setup, to: :@object

  delegate :prev_owned, to: :@object

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
