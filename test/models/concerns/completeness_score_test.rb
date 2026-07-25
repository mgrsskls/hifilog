# frozen_string_literal: true

require 'test_helper'

# The completeness score exists twice: in Ruby (Completeness#completeness_score, used for the
# prompts) and in SQL (a generated column on brands, an expression in the product_items view,
# used for sorting). Nothing stops the two from drifting apart except this test.
#
# If you change a weight, change it in all three places: the concern or model, the brands
# migration, and db/views/product_items_vNN.sql.
class CompletenessScoreTest < ActiveSupport::TestCase
  def product_item_for(product)
    ProductItem.find_by(product_id: product.id, item_type: 'Product')
  end

  def variant_item_for(variant)
    ProductItem.find_by(product_variant_id: variant.id, item_type: 'ProductVariant')
  end

  test 'every fixture brand scores the same in Ruby and in SQL' do
    Brand.find_each do |brand|
      assert_equal brand.completeness_score, brand.completeness,
                   "brand #{brand.name}: Ruby #{brand.completeness_score}, SQL #{brand.completeness}"
    end
  end

  test 'every fixture product scores the same in Ruby and in the view' do
    Product.find_each do |product|
      item = product_item_for(product)

      assert_not_nil item, "no product_items row for #{product.name}"
      assert_equal product.completeness_score, item.completeness,
                   "product #{product.name}: Ruby #{product.completeness_score}, SQL #{item.completeness}"
    end
  end

  test 'every fixture variant scores the same in Ruby and in the view' do
    ProductVariant.find_each do |variant|
      item = variant_item_for(variant)

      assert_not_nil item, "no product_items row for variant #{variant.id}"
      assert_equal variant.completeness_score, item.completeness,
                   "variant #{variant.id}: Ruby #{variant.completeness_score}, SQL #{item.completeness}"
    end
  end

  test 'brand scores agree across every combination of the fields that count' do
    # A brand with no products, so the sweep does not touch ten product rows on every update.
    brand = Brand.create!(name: 'Score Combo Brand', sub_category_ids: [sub_categories(:one).id])

    [nil, true, false].each do |discontinued|
      [nil, 1982].each do |discontinued_year|
        [nil, 'Some brand text.'].each do |description|
          [nil, 'DE'].each do |country_code|
            [nil, 1970].each do |founded_year|
              [nil, 'https://example.com'].each do |website|
                brand.update!(discontinued:, discontinued_year:, description:,
                              country_code:, founded_year:, website:)
                fresh = Brand.find(brand.id)

                assert_equal fresh.completeness_score, fresh.completeness,
                             "discontinued=#{discontinued.inspect} " \
                             "discontinued_year=#{discontinued_year.inspect} " \
                             "description=#{description.inspect} country=#{country_code.inspect} " \
                             "founded=#{founded_year.inspect} website=#{website.inspect}"
              end
            end
          end
        end
      end
    end
  end

  test 'a brand with products scores the same in Ruby and in SQL when discontinued' do
    brand = brands(:one)

    assert_predicate brand.products_count, :positive?

    brand.update!(discontinued: true, discontinued_year: 1982, website: 'https://example.com')

    assert_equal Brand.find(brand.id).completeness_score, Brand.find(brand.id).completeness
  end

  test 'a brand with no products scores the same in Ruby and in SQL' do
    empty = Brand.create!(
      name: 'Score Empty Brand',
      sub_category_ids: [sub_categories(:one).id],
      description: 'Text',
      country_code: 'DE',
      discontinued: false,
      founded_year: 1970,
      website: 'https://example.com'
    )

    assert_equal 0, empty.products_count
    assert_equal empty.completeness_score, Brand.find(empty.id).completeness
  end

  test 'product scores agree across every combination of fields and spec states' do
    product = products(:one)
    label = custom_attributes(:one).label

    assert_includes product.applicable_highlighted_attributes, label

    [{}, { label => '' }, { label => '1' }].each do |custom|
      [nil, 'Some product text.'].each do |description|
        [nil, 1978].each do |release_year|
          [[false, nil], [true, nil], [true, 1982]].each do |discontinued, discontinued_year|
            product.update!(custom_attributes: custom, description:, release_year:,
                            discontinued:, discontinued_year:)
            fresh = Product.find(product.id)
            item = product_item_for(fresh)

            assert_equal fresh.completeness_score, item.completeness,
                         "custom=#{custom.inspect} description=#{description.inspect} " \
                         "release_year=#{release_year.inspect} discontinued=#{discontinued} " \
                         "discontinued_year=#{discontinued_year.inspect}"
          end
        end
      end
    end
  end

  test 'a product whose categories define no highlighted specs agrees in Ruby and in SQL' do
    product = products(:two)

    assert_empty product.applicable_highlighted_attributes

    [nil, 'Some product text.'].each do |description|
      [nil, 1978].each do |release_year|
        product.update!(description:, release_year:)
        fresh = Product.find(product.id)

        assert_equal fresh.completeness_score, product_item_for(fresh).completeness,
                     "description=#{description.inspect} release_year=#{release_year.inspect}"
      end
    end
  end

  test 'variant scores agree across every combination of the fields that count' do
    variant = product_variants(:one)

    [nil, 'Some variant text.'].each do |description|
      [nil, 1990].each do |release_year|
        [[false, nil], [true, nil], [true, 1995]].each do |discontinued, discontinued_year|
          variant.update!(description:, release_year:, discontinued:, discontinued_year:)
          fresh = ProductVariant.find(variant.id)

          assert_equal fresh.completeness_score, variant_item_for(fresh).completeness,
                       "description=#{description.inspect} release_year=#{release_year.inspect} " \
                       "discontinued=#{discontinued} discontinued_year=#{discontinued_year.inspect}"
        end
      end
    end
  end

  test 'the view reports how many highlighted specs apply and how many are filled' do
    product = products(:one)
    label = custom_attributes(:one).label

    product.update!(custom_attributes: {})
    item = product_item_for(product)

    assert_equal 1, item.specs_applicable
    assert_equal 0, item.specs_filled

    product.update!(custom_attributes: { label => '1' })
    item = product_item_for(product)

    assert_equal 1, item.specs_applicable
    assert_equal 1, item.specs_filled
  end

  test 'variant rows report no applicable specs' do
    item = variant_item_for(product_variants(:one))

    assert_equal 0, item.specs_applicable
    assert_equal 0, item.specs_filled
  end
end
