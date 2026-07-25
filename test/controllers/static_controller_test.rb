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

  # Regression: these routes used to be constrained on the negotiated request format, so any
  # client that did not negotiate to HTML fell through to the '*url' catch-all and got a 404.
  test 'static pages render regardless of the Accept header' do
    paths = [
      changelog_path,
      about_path,
      imprint_path,
      privacy_policy_path,
      calculators_root_path,
      calculators_resistors_for_amplifier_to_headphone_adapter_path
    ]

    ['*/*', 'text/plain', 'application/json', ''].each do |accept|
      paths.each do |path|
        get path, headers: { 'HTTP_ACCEPT' => accept }
        assert_response :success, "#{path} should render HTML for Accept: #{accept.inspect}"
        assert_equal 'text/html', response.media_type
      end
    end
  end

  test 'static pages 404 for an explicit non-html extension' do
    get '/about.json'
    assert_response :not_found
  end

  test 'about path helper does not append a format extension' do
    assert_equal '/about', about_path
  end
end
