# frozen_string_literal: true

require 'test_helper'

class CompletenessTest < ActiveSupport::TestCase
  test 'product reports the fields it is missing' do
    product = products(:one)
    product.update!(release_year: nil, description: nil)

    assert_equal [:description, :release_year], product.missing_fields
    assert_predicate product, :incomplete?
  end

  test 'product with everything filled in is complete' do
    product = products(:one)
    product.update!(
      release_year: 1978,
      description: 'A headphone amplifier.',
      custom_attributes: { custom_attributes(:one).label => '1' }
    )

    assert_empty product.missing_fields
    assert_empty product.missing_highlighted_attributes
    assert_predicate product, :complete?
    assert_equal 100, product.completeness_score
  end

  test 'product counts a missing highlighted custom attribute as a gap' do
    product = products(:one)
    product.update!(custom_attributes: {})

    assert_predicate custom_attributes(:one), :highlighted
    assert_includes product.missing_highlighted_attributes, custom_attributes(:one).label
    assert_predicate product, :incomplete?
  end

  test 'product ignores custom attributes that are not highlighted' do
    product = products(:one)
    product.update!(custom_attributes: {})

    assert_not_predicate custom_attributes(:two), :highlighted
    assert_not_includes product.missing_highlighted_attributes, custom_attributes(:two).label
  end

  test 'a spec key holding an empty value counts as unfilled' do
    product = products(:one)
    label = custom_attributes(:one).label

    product.update!(custom_attributes: { label => '' })

    assert_includes product.missing_highlighted_attributes, label
  end

  test 'closing the spec set is worth more than the fraction alone' do
    product = products(:one)
    label = custom_attributes(:one).label
    product.update!(description: nil, release_year: nil, custom_attributes: {})

    assert_equal 0, product.completeness_score

    product.update!(custom_attributes: { label => '1' })

    # The single applicable spec is now filled: 2 points for the fraction plus the closing point.
    assert_equal 38, product.completeness_score
  end

  test 'a product with no applicable specs is scored out of the remaining fields' do
    product = products(:two)

    assert_empty product.applicable_highlighted_attributes

    product.update!(description: 'Headphones.', release_year: nil)

    assert_equal 60, product.completeness_score
  end

  test 'brand reports the fields it is missing' do
    brand = brands(:one)

    assert_predicate brand.country_code, :present?
    assert_equal [:description, :discontinued, :founded_year, :website], brand.missing_fields
  end

  test 'a brand that is out of business is not asked for a website' do
    brand = brands(:three)

    assert_predicate brand, :discontinued?
    assert_not_includes brand.completeness_fields, :website
    assert_not_includes brand.missing_fields, :website
  end

  test 'discontinued counts as answered when it is false, not only when true' do
    brand = brands(:one)

    assert_nil brand.discontinued
    assert_includes brand.missing_fields, :discontinued

    brand.update!(discontinued: false)

    assert_not_includes brand.missing_fields, :discontinued
  end

  test 'a discontinued product is asked for the year it was discontinued' do
    product = products(:one)
    product.update!(
      description: 'A headphone amplifier.',
      release_year: 1978,
      custom_attributes: { custom_attributes(:one).label => '1' }
    )

    assert_not_includes product.completeness_fields, :discontinued_year
    assert_equal 100, product.completeness_score

    product.update!(discontinued: true)

    assert_includes product.completeness_fields, :discontinued_year
    assert_includes product.missing_fields, :discontinued_year
    assert_equal 89, product.completeness_score

    product.update!(discontinued_year: 1982)

    assert_equal 100, product.completeness_score
  end

  test 'a discontinued variant is asked for the year it was discontinued' do
    variant = product_variants(:one)

    assert_not_includes variant.completeness_fields, :discontinued_year
    assert_equal 100, variant.completeness_score

    variant.update!(discontinued: true)

    assert_includes variant.missing_fields, :discontinued_year
    assert_equal 83, variant.completeness_score

    variant.update!(discontinued_year: 2005)

    assert_equal 100, variant.completeness_score
  end

  test 'a discontinued brand swaps website for the year it closed' do
    brand = brands(:one)
    brand.update!(discontinued: false)

    assert_includes brand.completeness_fields, :website
    assert_not_includes brand.completeness_fields, :discontinued_year

    brand.update!(discontinued: true)

    assert_not_includes brand.completeness_fields, :website
    assert_includes brand.completeness_fields, :discontinued_year
  end

  test 'a brand can reach 100 per cent whether or not it is discontinued' do
    brand = brands(:one)
    brand.update!(description: 'Text', country_code: 'DE', founded_year: 1970,
                  discontinued: false, website: 'https://example.com')

    assert_predicate brand.products_count, :positive?
    assert_equal 100, brand.completeness_score

    brand.update!(discontinued: true, discontinued_year: 1982)

    assert_equal 100, brand.completeness_score
  end

  test 'brands have no key specs to miss' do
    assert_empty brands(:one).missing_highlighted_attributes
  end

  test 'having products dominates a brand score' do
    empty = Brand.create!(name: 'Completeness Empty Brand', sub_category_ids: [sub_categories(:one).id])

    assert_equal 0, empty.completeness_score

    empty.update!(description: 'Text', country_code: 'DE', discontinued: false,
                  founded_year: 1970, website: 'https://example.com')

    # Everything except products: 9 of 14.
    assert_equal 64, empty.completeness_score
  end

  test 'variant completeness uses the variants own fields' do
    variant = product_variants(:one)

    assert_empty variant.missing_fields
    assert_predicate variant, :complete?
    assert_equal 100, variant.completeness_score

    variant.update!(description: nil)

    assert_equal [:description], variant.missing_fields
    assert_equal 40, variant.completeness_score
  end

  test 'variants do not inherit the parents key specs' do
    assert_empty product_variants(:one).missing_highlighted_attributes
  end

  test 'ContributeProductItem.incomplete covers variants as well as products' do
    assert_includes ContributeProductItem.incomplete.map(&:product_id), products(:two).id
    assert_includes ContributeProductItem.incomplete.map(&:product_variant_id), product_variants(:three).id
  end

  test 'ContributeProductItem.missing_specs finds entries with specs to give that have not given them all' do
    products(:one).update!(custom_attributes: {})

    assert_includes ContributeProductItem.missing_specs.map(&:product_id), products(:one).id
    assert_not_includes ContributeProductItem.missing_specs.map(&:product_id), products(:with_custom_attributes).id
  end

  test 'ContributeProductItem.missing_specs never lists a variant' do
    assert_empty ContributeProductItem.missing_specs.where(item_type: 'ProductVariant')
  end

  test 'Brand.without_products finds brands with an empty catalogue' do
    empty = Brand.create!(name: 'Completeness Empty Brand', sub_category_ids: [sub_categories(:one).id])

    assert_includes Brand.without_products, empty
    assert_not_includes Brand.without_products, brands(:one)
  end

  test 'Brand.missing_website includes brands whose status is unknown' do
    brand = brands(:one)
    brand.update!(website: nil)

    assert_nil brand.discontinued
    assert_includes brand.missing_fields, :website
    assert_includes Brand.missing_website, brand
  end

  test 'Brand.missing_website includes brands still in business' do
    brand = brands(:one)
    brand.update!(website: nil, discontinued: false)

    assert_includes Brand.missing_website, brand
  end

  test 'Brand.missing_website excludes brands that are out of business' do
    brand = brands(:three)
    brand.update!(website: nil)

    assert_predicate brand, :discontinued?
    assert_not_includes brand.completeness_fields, :website
    assert_not_includes Brand.missing_website, brand
  end

  test 'Brand.missing_website excludes brands that have one' do
    brand = brands(:one)
    brand.update!(website: 'https://example.com')

    assert_not_includes Brand.missing_website, brand
  end

  test 'Brand.missing_discontinued finds brands with no answer either way' do
    unknown = brands(:one)

    assert_nil unknown.discontinued
    assert_includes Brand.missing_discontinued, unknown
    assert_not_includes Brand.missing_discontinued, brands(:three)

    unknown.update!(discontinued: false)

    assert_not_includes Brand.missing_discontinued, unknown
  end

  test 'Brand.missing_discontinued_year only asks brands that are out of business' do
    closed = brands(:three)

    assert_nil closed.discontinued_year
    assert_includes Brand.missing_discontinued_year, closed
    assert_not_includes Brand.missing_discontinued_year, brands(:one)

    closed.update!(discontinued_year: 1990)

    assert_not_includes Brand.missing_discontinued_year, closed
  end

  test 'Brand.missing_founded_year, missing_country_code and missing_description' do
    brand = brands(:one)

    assert_includes Brand.missing_founded_year, brand
    assert_includes Brand.missing_description, brand
    assert_not_includes Brand.missing_country_code, brand

    brand.update!(founded_year: 1970, description: 'Text', country_code: nil)

    assert_not_includes Brand.missing_founded_year, brand
    assert_not_includes Brand.missing_description, brand
    assert_includes Brand.missing_country_code, brand
  end

  test 'ContributeProductItem.missing_discontinued_year only lists discontinued entries' do
    discontinued = products(:discontinued)
    listed = -> { ContributeProductItem.missing_discontinued_year.map(&:product_id) }

    assert_predicate discontinued, :discontinued?
    assert_nil discontinued.discontinued_year
    assert_includes listed.call, discontinued.id
    assert_not_includes listed.call, products(:one).id

    discontinued.update!(discontinued_year: 1982)

    assert_not_includes listed.call, discontinued.id
  end

  # The queue filters and the completeness score are two descriptions of the same thing, so they
  # have to agree field by field. This is the assertion that would have caught Brand.missing_website
  # silently dropping every brand whose status is unknown.
  test 'every brand missing scope agrees with that brands completeness fields' do
    Brand.find_each do |brand|
      Brand::COMPLETENESS_WEIGHTS.each_key do |field|
        expected = brand.missing_fields.include?(field)
        listed = Brand.public_send(:"missing_#{field}").exists?(id: brand.id)

        assert_equal expected, listed,
                     "#{brand.name}: completeness #{expected ? 'counts' : 'does not count'} " \
                     "#{field} as missing, but Brand.missing_#{field} disagrees"
      end
    end
  end

  test 'every product missing scope agrees with that products completeness fields' do
    Product.find_each do |product|
      item = ContributeProductItem.find_by(product_id: product.id, item_type: 'Product')

      Product::COMPLETENESS_WEIGHTS.each_key do |field|
        expected = product.missing_fields.include?(field)
        listed = ContributeProductItem.public_send(:"missing_#{field}").exists?(id: item.id)

        assert_equal expected, listed,
                     "#{product.name}: completeness #{expected ? 'counts' : 'does not count'} " \
                     "#{field} as missing, but ContributeProductItem.missing_#{field} disagrees"
      end
    end
  end

  test 'a variant is judged on its own description, not its parents' do
    variant = product_variants(:one)
    item = ContributeProductItem.find_by(product_variant_id: variant.id, item_type: 'ProductVariant')

    assert_nil variant.product.description
    assert_predicate variant.description, :present?
    assert_not_includes variant.missing_fields, :description
    assert_not ContributeProductItem.missing_description.exists?(id: item.id)

    variant.update!(description: nil)

    assert_includes variant.missing_fields, :description
    assert ContributeProductItem.missing_description.exists?(id: item.id)
  end

  test 'a product is still judged on its own description' do
    product = products(:with_variants)
    item = ContributeProductItem.find_by(product_id: product.id, item_type: 'Product')

    assert_nil product.description
    assert ContributeProductItem.missing_description.exists?(id: item.id)

    product.update!(description: 'Some text.')

    assert_not ContributeProductItem.missing_description.exists?(id: item.id)
  end

  test 'every variant missing scope agrees with that variants completeness fields' do
    ProductVariant.find_each do |variant|
      item = ContributeProductItem.find_by(product_variant_id: variant.id, item_type: 'ProductVariant')

      ProductVariant::COMPLETENESS_WEIGHTS.each_key do |field|
        expected = variant.missing_fields.include?(field)
        listed = ContributeProductItem.public_send(:"missing_#{field}").exists?(id: item.id)

        assert_equal expected, listed,
                     "variant #{variant.id}: completeness #{expected ? 'counts' : 'does not count'} " \
                     "#{field} as missing, but ContributeProductItem.missing_#{field} disagrees"
      end
    end
  end
end
