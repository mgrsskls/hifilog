# frozen_string_literal: true

require 'test_helper'

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test 'show' do
    user = users(:one)

    get product_url(id: user.products.first.friendly_id)
    assert_response :success

    sign_in users(:one)

    get product_url(id: possessions(:current_product).product.friendly_id)
    assert_response :success

    get product_url(id: possessions(:prev_product).product.friendly_id)
    assert_response :success
  end

  test 'show renders catalog data for guest' do
    product = products(:one)

    get product_url(id: product.friendly_id)

    assert_response :success
    assert_select 'dt', text: I18n.t('headings.contributors')
    assert_select '.EntityPossession', count: 0
  end

  test 'show renders catalog data for signed-in user' do
    product = products(:one)

    sign_in users(:one)

    get product_url(id: product.friendly_id)

    assert_response :success
    assert_select '.EntityPossession', minimum: 1
    assert_select 'dt', text: I18n.t('headings.contributors')
  end

  test 'show renders community image gallery when visible possessions have images' do
    product = products(:one)
    possessions(:current_product).update!(images: [one_by_one_png_upload(filename: 'catalog-gallery.png')])

    get product_url(id: product.friendly_id)

    assert_response :success
    assert_select 'ul.Entity-image.ImageLightbox'
  end

  test 'new' do
    get new_product_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get new_product_url
    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'

    get new_product_url(sub_category: sub_categories(:one).slug)
    assert_response :success

    get new_product_url(brand_id: brands(:one).id)
    assert_response :success
  end

  test 'create' do
    brand = brands(:one)
    params = {
      product: {
        sub_category_ids: [brand.products.first.sub_categories.first.id],
        discontinued: false,
        product_options_attributes: {
          0 => { option: 'option' }
        }
      }
    }

    post products_url, params: params.deep_merge(
      {
        product: {
          name: 'product name',
          brand_id: brand.id
        }
      }
    )
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    # with existing brand
    # with sub category which is already sub category of brand
    post products_url, params: params.deep_merge(
      {
        product: {
          name: 'product name',
          brand_id: brand.id
        }
      }
    )
    assert_response :redirect
    assert_redirected_to product_url(id: Product.last.friendly_id)

    sub_category = SubCategory.create!(name: 'sub category', category_id: categories(:one).id)

    # with existing brand
    # with sub category which is not yet sub category of brand
    post products_url, params: params.deep_merge(
      {
        product: {
          name: 'product name 2',
          sub_category_ids: [sub_category.id],
          brand_id: brand.id
        }
      }
    )
    assert_response :redirect
    assert_redirected_to product_url(id: Product.last.friendly_id)

    # with new brand
    post products_url, params: params.deep_merge(
      {
        product: {
          name: 'product name 3',
          brand_attributes: {
            name: 'brand name'
          }
        }
      }
    )
    assert_response :redirect
    assert_redirected_to product_url(id: Product.last.friendly_id)

    # with invalid new brand
    post products_url, params: params.deep_merge(
      {
        product: {
          name: 'product name 4',
          brand_attributes: {}
        }
      }
    )
    assert_response :unprocessable_content
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end

  test 'edit' do
    path = edit_product_url(id: products(:one).slug)

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get path
    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end

  test 'update' do
    product = products(:one)
    name = 'new name'
    params = {
      product: {
        name:,
        discontinued: !product.discontinued
      },
      product_options_attributes: {
        0 => {
          id: product.product_options.first.id,
          option: 'new option name'
        },
        1 => {
          id: product.product_options.second.id,
          option: ''
        },
        2 => {
          option: 'new option'
        },
        3 => {
          option: ''
        }
      }
    }

    patch product_url(id: product.id), params: params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    patch product_url(id: product.id), params: params
    assert_response :redirect
    assert_redirected_to product_url(id: Product.find(product.id).friendly_id)
  end

  test 'changelog' do
    get product_changelog_url(product_id: products(:one).friendly_id)
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
    assert_response :success
  end

  # Regression: ApplicationController#not_found used to re-render the changelog template for a
  # missing record, which blew up on the nil @product instead of returning a 404.
  test 'changelog returns 404 for an unknown product' do
    get product_changelog_url(product_id: 'no-such-product')

    assert_response :not_found
  end

  # Pins per-version attribution: a version with no whodunnit is credited to hifilog.com even
  # when the version rendered directly above it has a known author. Correct today because the
  # author is a block-local, but it is one refactor away from breaking silently.
  test 'changelog credits each version to its own author' do
    product = products(:one)

    product.update!(name: 'Changelog attribution older') # no whodunnit outside a request
    PaperTrail.request(whodunnit: users(:one).id.to_s) do
      product.update!(name: 'Changelog attribution newer')
    end

    get product_changelog_url(product_id: product.reload.friendly_id)
    assert_response :success

    headings = css_select('.Changelog-itemHeading').map(&:text)

    assert_equal 2, headings.size
    assert_equal(1, headings.count { |heading| heading.include?('hifilog.com') })
    assert_equal(1, headings.count { |heading| heading.include?(users(:one).user_name) })
  end

  test 'create persists custom_attributes for boolean and number types' do
    brand = brands(:one)
    sub_category = brand.sub_categories.first

    params = {
      product: {
        name: 'Custom attributes product xyz',
        brand_id: brand.id,
        discontinued: false,
        sub_category_ids: [sub_category.id],
        custom_attributes: {
          'loudspeaker_bi_wiring' => 'true',
          'weight' => { 'value' => '42', 'unit' => 'cm' }
        },
        product_options_attributes: {}
      }
    }

    sign_in users(:one)

    assert_difference(-> { Product.where(name: 'Custom attributes product xyz').count }, 1) do
      post products_url, params:
    end

    assert_response :redirect

    saved = Product.find_by!(name: 'Custom attributes product xyz')
    assert_equal true, saved.custom_attributes['loudspeaker_bi_wiring']
    assert_in_delta 42.0, saved.custom_attributes.dig('weight', 'value')
  ensure
    saved&.destroy
  end

  # `to_f` read "0,5" as 0.0, so a contributor using a decimal comma silently wrote a measured
  # zero. Unreadable is now treated as unanswered, which the completeness prompts ask about
  # again instead of accepting.
  test 'create drops a number it cannot read rather than storing it as zero' do
    brand = brands(:one)
    sub_category = brand.sub_categories.first

    sign_in users(:one)

    post products_url, params: {
      product: {
        name: 'Unreadable number product xyz',
        brand_id: brand.id,
        discontinued: false,
        sub_category_ids: [sub_category.id],
        custom_attributes: {
          'weight' => { 'value' => '0,5', 'unit' => 'kg' }
        },
        product_options_attributes: {}
      }
    }

    saved = Product.find_by!(name: 'Unreadable number product xyz')

    assert_not saved.custom_attributes.key?('weight')
  ensure
    saved&.destroy
  end

  # Used to raise on `active_record.input_type`. A form rendered before a label was renamed
  # submits exactly this, so it has to be an ignored key rather than a 500 -- and an ignored
  # key nothing can interpret has no business being persisted either.
  test 'create drops a custom attribute label no definition backs' do
    brand = brands(:one)
    sub_category = brand.sub_categories.first

    sign_in users(:one)

    post products_url, params: {
      product: {
        name: 'Unknown attribute product xyz',
        brand_id: brand.id,
        discontinued: false,
        sub_category_ids: [sub_category.id],
        custom_attributes: {
          'no_such_attribute' => { 'value' => '5', 'unit' => 'kg' },
          'weight' => { 'value' => '3', 'unit' => 'kg' }
        },
        product_options_attributes: {}
      }
    }

    assert_response :redirect

    saved = Product.find_by!(name: 'Unknown attribute product xyz')

    assert_not saved.custom_attributes.key?('no_such_attribute')
    assert_in_delta 3.0, saved.custom_attributes.dig('weight', 'value')
  ensure
    saved&.destroy
  end

  test 'create keeps only the readable inputs of a multi input number' do
    brand = brands(:one)
    sub_category = brand.sub_categories.first

    sign_in users(:one)

    post products_url, params: {
      product: {
        name: 'Partial dimensions product xyz',
        brand_id: brand.id,
        discontinued: false,
        sub_category_ids: [sub_category.id],
        custom_attributes: {
          'dimensions' => { 'value' => { 'w' => '10', 'h' => '', 'l' => 'tall' }, 'unit' => 'cm' }
        },
        product_options_attributes: {}
      }
    }

    saved = Product.find_by!(name: 'Partial dimensions product xyz')

    assert_in_delta 10.0, saved.custom_attributes.dig('dimensions', 'value', 'w')
    assert_equal %w[w], saved.custom_attributes.dig('dimensions', 'value').keys
  ensure
    saved&.destroy
  end

  # A custom_attributes key with no backing CustomAttribute definition -- crafted, or stale
  # after a label rename -- used to reach `active_record.input_type` on nil and 500. It is now
  # dropped rather than cast (see discard_unknown_custom_attributes!), so the rest of the
  # submission still saves -- even when dropping leaves custom_attributes empty, as it does here.
  test 'create does not error on a custom_attributes key with no matching definition' do
    brand = brands(:one)
    sub_category = brand.sub_categories.first

    sign_in users(:one)

    post products_url, params: {
      product: {
        name: 'Unknown custom attribute product xyz',
        brand_id: brand.id,
        discontinued: false,
        sub_category_ids: [sub_category.id],
        custom_attributes: {
          'not_a_real_attribute' => { 'value' => '1', 'unit' => 'kg' }
        },
        product_options_attributes: {}
      }
    }

    assert_response :redirect

    saved = Product.find_by!(name: 'Unknown custom attribute product xyz')
  ensure
    saved&.destroy
  end

  test 'create with invalid brand renders new with product_options applied to in-memory record' do
    sub_category_id = categories(:one).sub_categories.first.id

    params = {
      product: {
        name: 'Brand fail options',
        sub_category_ids: [sub_category_id],
        discontinued: false,
        product_options_attributes: {
          0 => { option: 'wired' }
        },
        brand_attributes: {
          name: ''
        }
      }
    }

    sign_in users(:one)

    assert_no_difference('Product.count') do
      post products_url, params:
    end

    assert_response :unprocessable_content
  end

  test 'update rejects invalid payload and renders edit with categories' do
    product = products(:one)

    sign_in users(:one)

    patch product_url(id: product.id), params: {
      product: {
        name: '',
        discontinued: product.discontinued
      },
      product_options_attributes: {}
    }

    assert_response :unprocessable_content
    assert_predicate response.body, :present?
  end

  test 'update changes friendly id when name changes and applies custom_attribute params' do
    product = products(:release_date_y)
    slug_before = product.friendly_id

    sign_in users(:one)

    patch product_url(id: product.id), params: {
      product: {
        name: 'Renamed release product',
        discontinued: product.discontinued,
        sub_category_ids: product.sub_categories.map(&:id)
      }
    }

    assert_response :redirect
    product.reload
    assert_equal 'Renamed release product', product.name
    assert_not_equal slug_before, product.friendly_id

    patch product_url(id: product.id), params: {
      product: {
        name: 'Renamed release product',
        model_no: 'x-no',
        discontinued: product.discontinued,
        sub_category_ids: product.sub_categories.map(&:id),
        custom_attributes: {
          'loudspeaker_bi_wiring' => 'false',
          'weight' => { 'value' => '11', 'unit' => 'cm' }
        }
      }
    }

    assert_response :redirect

    product.reload

    assert_equal false, product.custom_attributes['loudspeaker_bi_wiring']
    assert_in_delta 11.0, product.custom_attributes.dig('weight', 'value')
  end

  test 'create mirrors brand discontinued flag onto the catalogue record when brand halted production' do
    brand = brands(:one)
    mirror = nil
    sub_category_id = categories(:one).sub_categories.pick(:id)
    brand.update!(discontinued: true)

    sign_in users(:one)

    post products_url, params: {
      product: {
        name: 'Discontinued brand mirror',
        brand_id: brand.id,
        discontinued: false,
        sub_category_ids: [sub_category_id],
        product_options_attributes: {}
      }
    }

    assert_response :redirect
    mirror = Product.find_by!(name: 'Discontinued brand mirror')
    assert mirror.discontinued?
    assert_predicate brand.reload, :discontinued?
  ensure
    mirror&.destroy
    brand&.update!(discontinued: false)
  end

  test 'create stops on invalid catalogue payload after brand persists' do
    template = products(:one)
    sign_in users(:one)

    assert_no_difference(-> { Product.count }) do
      post products_url, params: {
        product: {
          name: '',
          brand_id: template.brand_id,
          discontinued: false,
          sub_category_ids: template.sub_categories.map(&:id),
          product_options_attributes: {}
        }
      }
    end

    assert_response :unprocessable_content
  end
end
