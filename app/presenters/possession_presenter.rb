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
end
