# frozen_string_literal: true

class PossessionPresenterService
  def self.map_to_presenters(possessions)
    possessions.map do |possession|
      if possession.custom_product_id
        CustomProductPossessionPresenter.new(possession)
      elsif possession.prev_owned
        PreviousPossessionPresenter.new(possession)
      else
        CurrentPossessionPresenter.new(possession)
      end
    end
  end
end
