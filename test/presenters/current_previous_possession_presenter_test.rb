# frozen_string_literal: true

require 'test_helper'

class CurrentPreviousPossessionPresenterTest < ActiveSupport::TestCase
  test 'differentiates removal copy between active and archival collections' do
    prev = PreviousPossessionPresenter.new(possessions(:prev_product))
    current = PossessionPresenter.new(possessions(:current_product))

    assert_equal prev.delete_button_label, current.delete_button_label
    assert_not_equal prev.delete_confirm_msg, current.delete_confirm_msg
  end
end
