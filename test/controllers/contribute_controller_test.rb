# frozen_string_literal: true

require 'test_helper'

class ContributeControllerTest < ActionDispatch::IntegrationTest
  def empty_brand(name: 'Contribute Empty Brand', sub_category: :one)
    Brand.create!(name:, sub_category_ids: [sub_categories(sub_category).id])
  end

  test 'index' do
    get contribute_root_url

    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end

  test 'index links to every queue' do
    get contribute_root_url

    assert_select 'a[href=?]', contribute_brands_without_products_path
    assert_select 'a[href=?]', contribute_incomplete_brands_path
    assert_select 'a[href=?]', contribute_incomplete_products_path
  end

  test 'brands without products lists only brands with an empty catalogue' do
    empty = empty_brand

    get contribute_brands_without_products_url

    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'

    list = css_select('.EntityList--brands').to_s

    assert_includes list, empty.name
    assert_not_includes list, brands(:one).name
  end

  test 'brands without products can be narrowed to a category' do
    empty = empty_brand

    get contribute_brands_without_products_url(category: categories(:one).friendly_id)

    assert_response :success
    assert_includes css_select('.EntityList--brands').to_s, empty.name

    get contribute_brands_without_products_url(category: categories(:two).friendly_id)

    assert_response :success
    assert_not_includes css_select('.EntityList--brands').to_s, empty.name
  end

  test 'brands without products shows an empty state when nothing matches' do
    get contribute_brands_without_products_url

    assert_response :success
    assert_select '.EmptyState'
  end

  test 'incomplete products lists entries that are missing details' do
    get contribute_incomplete_products_url

    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
    assert_includes css_select('.EntityList--products').to_s, products(:two).name
  end

  test 'incomplete products can be narrowed to a single missing detail' do
    products(:one).update!(release_year: 1978)

    get contribute_incomplete_products_url(missing: 'release_year')

    assert_response :success

    list = css_select('.EntityList--products').to_s

    assert_not_includes list, products(:one).name
    assert_includes list, products(:two).name
  end

  test 'an unrecognised missing filter falls back to the full queue' do
    get contribute_incomplete_products_url(missing: 'nonsense')

    assert_response :success
    assert_includes css_select('.EntityList--products').to_s, products(:two).name
  end

  test 'an unknown category is not found' do
    get contribute_brands_without_products_url(category: 'no-such-category')

    assert_response :not_found

    get contribute_incomplete_products_url(category: 'no-such-category')

    assert_response :not_found
  end

  test 'incomplete brands lists brands that are missing details' do
    get contribute_incomplete_brands_url

    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
    assert_includes css_select('.EntityList--brands').to_s, brands(:one).name
  end

  test 'incomplete brands can be narrowed to a single missing detail' do
    with_website = brands(:one)
    with_website.update!(website: 'https://example.com')

    get contribute_incomplete_brands_url(missing: 'website')

    assert_response :success

    list = css_select('.EntityList--brands').to_s

    assert_not_includes list, with_website.name
    assert_includes list, brands(:two).name
  end

  test 'incomplete brands can be narrowed to brands with no categories' do
    uncategorised = Brand.create!(name: 'Contribute Uncategorised Brand')

    get contribute_incomplete_brands_url(missing: 'sub_categories')

    assert_response :success

    list = css_select('.EntityList--brands').to_s

    assert_includes list, uncategorised.name
    assert_not_includes list, brands(:one).name
  end

  test 'the website filter still lists a brand whose status is unknown' do
    brand = brands(:one)

    assert_nil brand.discontinued
    assert_nil brand.website

    get contribute_incomplete_brands_url(missing: 'website')

    assert_includes css_select('.EntityList--brands').to_s, brand.name
  end

  test 'incomplete brands can be narrowed to a category' do
    get contribute_incomplete_brands_url(category: categories(:one).friendly_id)

    assert_response :success
    assert_includes css_select('.EntityList--brands').to_s, brands(:one).name

    get contribute_incomplete_brands_url(category: categories(:two).friendly_id)

    assert_response :success
    assert_not_includes css_select('.EntityList--brands').to_s, brands(:one).name
  end

  test 'an unknown category is not found on the incomplete brands queue' do
    get contribute_incomplete_brands_url(category: 'no-such-category')

    assert_response :not_found
  end

  # sub_category_names is no longer a column on the view — it is preloaded per page. Without this
  # the controller could stop preloading and the only symptom would be an empty category badge.
  test 'the products queue renders sub category names' do
    get contribute_incomplete_products_url

    assert_response :success
    assert_select '.EntityList--products .EntityListItem-data dd',
                  text: sub_categories(:two).name, minimum: 1
  end

  test 'the queues render a completeness bar' do
    get contribute_incomplete_products_url

    assert_select '.Completeness', minimum: 1

    get contribute_incomplete_brands_url

    assert_select '.Completeness', minimum: 1
  end
end
