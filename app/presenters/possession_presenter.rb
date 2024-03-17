class PossessionPresenter
  include Rails.application.routes.url_helpers

  delegate_missing_to :@object

  def initialize(object)
    @object = object

    if object.custom_product_id
      @presenter = CustomProductPresenter.new(object) if object.custom_product_id
      return
    end

    @presenter = ItemPresenter.new(object)
  end

  def display_name
    @presenter.display_name
  end
end
