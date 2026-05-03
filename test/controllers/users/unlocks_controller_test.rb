# frozen_string_literal: true

require 'test_helper'

class Users::UnlocksControllerTest < ActiveSupport::TestCase
  # Routes are omitted while `User` is not `:lockable`; this confirms the subclass
  # stays available for enabling lock/unlock flows later without drift from Devise.

  test 'inherits Devise unlock controller' do
    assert Users::UnlocksController < Devise::UnlocksController
  end
end
