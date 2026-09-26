# frozen_string_literal: true

require 'test_helper'

# Names in ActiveAdmin render as text. Users write custom product, product and option names, and an
# admin session has full access: HTML in such a name must not become markup there.
class AdminHtmlEscapingTest < ActionDispatch::IntegrationTest
  HTML = '<meta http-equiv="refresh" content="0;url=https://attacker.example/">'
  ESCAPED = ERB::Util.html_escape(HTML)

  setup do
    sign_in admin_users(:admin_user)
  end

  test 'possessions index escapes the custom product name' do
    users(:visible).custom_products.create!(name: HTML, sub_categories: [sub_categories(:one)])

    get admin_possessions_path

    assert_response :success
    assert_not_in_body HTML, 'the custom product name is markup'
    assert_in_body ESCAPED, 'the custom product name is missing'
  end

  test 'possessions index escapes the product option and shows it on its own line' do
    product_options(:one).update!(option: HTML)
    Possession.create!(user: users(:visible), product: products(:one), product_option: product_options(:one))

    get admin_possessions_path

    assert_response :success
    assert_not_in_body HTML, 'the option is markup'
    assert_in_body "<br><small>#{ESCAPED}</small>", 'the option is not on its own line'
  end

  test 'sub category groups on admin forms escape the category name' do
    categories(:one).update!(name: HTML)

    [
      edit_admin_product_path(products(:one)),
      edit_admin_brand_path(brands(:one)),
      edit_admin_custom_attribute_path(custom_attributes(:one))
    ].each do |path|
      get path

      assert_response :success, path
      assert_not_in_body HTML, "#{path}: the category name is markup"
      assert_in_body "<b>#{ESCAPED}</b>", "#{path}: the category name is not bold"
    end
  end

  private

  # Like assert_includes on response.body, but a failure prints the message and not the whole page.
  def assert_in_body(text, message)
    assert response.body.include?(text), message
  end

  def assert_not_in_body(text, message)
    assert_not response.body.include?(text), message
  end
end
