# frozen_string_literal: true

require 'test_helper'

class PossessionPresenterServiceTest < ActiveSupport::TestCase
  test 'maps catalogue possessions to specialised presenters by kind' do
    current = PossessionPresenterService.map_to_presenters(
      Possession.where(id: possessions(:current_product).id)
    )

    assert_instance_of PossessionPresenter, current.first

    previous = PossessionPresenterService.map_to_presenters(
      Possession.where(id: possessions(:prev_product).id)
    )

    assert_instance_of PreviousPossessionPresenter, previous.first

    customs = PossessionPresenterService.map_to_presenters(
      Possession.where(id: possessions(:current_custom_product).id)
    )

    assert_instance_of CustomProductPossessionPresenter, customs.first
  end
end
