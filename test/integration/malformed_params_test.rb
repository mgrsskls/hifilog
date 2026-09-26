# frozen_string_literal: true

require 'test_helper'

# A crafted page[]=1 or query[a]=x arrives as an array or a hash. The application reads these
# parameters as one value, so ApplicationController removes such a value, and the request continues
# as if it was not sent. Before, Kaminari or a String method raised on it (500).
class MalformedParamsTest < ActionDispatch::IntegrationTest
  test 'an array or a hash as page or query is ignored' do
    [
      '/products?page[]=1',
      '/brands/c/amplifiers?page[a]=1',
      "/brands/#{brands(:one).friendly_id}/similar?page[]=1",
      "/products/#{products(:one).friendly_id}?page[]=2",
      '/contribute/incomplete-products?page[]=1',
      '/search?query=abc&page[]=1'
    ].each do |path|
      get path

      assert_response :success, path
    end
  end

  test 'the search treats an array or a hash as query like no query' do
    ['/search?query[]=abc', '/search?query[a]=abc'].each do |path|
      get path

      assert_response :success, path
      assert_select 'main', text: /#{Regexp.escape(I18n.t('search_results.alert.minimum_chars', min: 2))}/
    end
  end

  test 'the dashboard feed ignores an array as page' do
    sign_in users(:one)

    get '/dashboard/feed?page[]=1'

    assert_response :success
  end

  test 'ActiveAdmin ignores an array as page' do
    sign_in admin_users(:admin_user)

    get '/admin/user_images?page[]=1'

    assert_response :success
  end

  test 'one value as page or query still works' do
    ['/products?page=1', '/brands/c/amplifiers?page=1', '/search?query=abc&page=1'].each do |path|
      get path

      assert_response :success, path
    end
  end
end
