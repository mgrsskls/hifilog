class ImagePresenter
  delegate_missing_to :@image

  def initialize(object)
    @image = object
  end

  def user
    return Possession.find(record_id).user if record_type == 'Possession'

    nil
  end
end
