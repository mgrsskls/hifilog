class PossessionPresenter < ItemPresenter
  include Rails.application.routes.url_helpers

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
end
