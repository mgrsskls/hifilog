# frozen_string_literal: true

class ImagePresenter
  delegate_missing_to :@image

  def initialize(object)
    @image = object
  end

  def user
    return @user if instance_variable_defined?(:@user)

    @user = possession_record&.user
  end

  private

  def possession_record
    return nil unless record_type == 'Possession'

    record = @image.record if @image.respond_to?(:record)
    record.is_a?(Possession) ? record : Possession.find_by(id: record_id)
  end
end
