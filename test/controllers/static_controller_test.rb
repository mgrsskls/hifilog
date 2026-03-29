# frozen_string_literal: true

require 'test_helper'

class StaticControllerTest < ActionDispatch::IntegrationTest
  test 'changelog' do
    get changelog_path
    assert_response :success
  end

  test 'about' do
    get about_path
    assert_response :success
  end

  test 'imprint' do
    get imprint_path
    assert_response :success
  end

  test 'privacy_policy' do
    get privacy_policy_path
    assert_response :success
  end

  test 'calculators' do
    get calculators_root_path
    assert_response :success
  end

  test 'amp_to_headphone_calculator' do
    get calculators_resistors_for_amplifier_to_headphone_adapter_path
    assert_response :success
  end
end
