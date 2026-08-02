# frozen_string_literal: true

require 'test_helper'

class ProductConversionServiceTest < ActiveSupport::TestCase
  setup do
    @product = products(:one)
    @target = products(:without_custom_attributes) # same brand as products(:one)
    @user = users(:one)
  end

  test 'converts a product into a variant of another product' do
    variant = ProductConversionService.to_variant(@product, @target)

    assert_equal @target, variant.product
    assert_equal 'Elise', variant.name
    assert_nil Product.find_by(id: @product.id)
  end

  test 'copies the shared attributes onto the new variant' do
    @product.update!(model_no: 'CONV-1', release_year: 1999, discontinued: true, discontinued_year: 2005)

    variant = ProductConversionService.to_variant(@product, @target)

    assert_equal 'CONV-1', variant.model_no
    assert_equal 1999, variant.release_year
    assert variant.discontinued
    assert_equal 2005, variant.discontinued_year
  end

  test 'accepts an explicit variant name' do
    variant = ProductConversionService.to_variant(@product, @target, name: 'Special Edition')

    assert_equal 'Special Edition', variant.name
  end

  test 'moves possessions, notes, options and bookmarks onto the variant' do
    possession = possessions(:current_product)
    note = notes(:one)
    option = product_options(:one)
    bookmark = bookmarks(:with_product)

    variant = ProductConversionService.to_variant(@product, @target)

    assert_equal [@target.id, variant.id], possession.reload.slice(:product_id, :product_variant_id).values
    assert_equal [@target.id, variant.id], note.reload.slice(:product_id, :product_variant_id).values
    assert_equal [nil, variant.id], option.reload.slice(:product_id, :product_variant_id).values
    assert_equal ['ProductVariant', variant.id], bookmark.reload.slice(:item_type, :item_id).values
  end

  test 'carries the paper trail history across' do
    @product.update!(name: 'Renamed')
    versions = @product.versions.count

    assert_predicate versions, :positive?

    variant = ProductConversionService.to_variant(@product, @target)

    # +1: the new variant logs its own create event, on top of the product's history moving over.
    assert_equal versions + 1, PaperTrail::Version.where(item_type: 'ProductVariant', item_id: variant.id).count
    assert_equal 0, PaperTrail::Version.where(item_type: 'Product', item_id: @product.id).count
  end

  test 'drops the old slug history' do
    ProductConversionService.to_variant(@product, @target)

    assert_equal 0, FriendlyId::Slug.where(sluggable_type: 'Product', sluggable_id: @product.id).count
  end

  test 'refuses to convert a product that has variants of its own' do
    parent = products(:with_variants)
    same_brand_target = products(:two)

    error = assert_raises(ProductConversionService::ConversionError) do
      ProductConversionService.to_variant(parent, same_brand_target)
    end

    assert_match(/variants of its own/, error.message)
    assert Product.exists?(parent.id)
  end

  test 'refuses to convert a product into a variant of another brand' do
    other_brand_target = products(:two)

    assert_not_equal @product.brand_id, other_brand_target.brand_id

    error = assert_raises(ProductConversionService::ConversionError) do
      ProductConversionService.to_variant(@product, other_brand_target)
    end

    assert_match(/same brand/, error.message)
    assert Product.exists?(@product.id)
  end

  test 'refuses to convert a product into a variant of itself' do
    assert_raises(ProductConversionService::ConversionError) do
      ProductConversionService.to_variant(@product, @product)
    end
  end

  test 'refuses to convert without a target product' do
    assert_raises(ProductConversionService::ConversionError) do
      ProductConversionService.to_variant(@product, nil)
    end
  end

  test 'leaves the product untouched when the variant is invalid' do
    @product.update!(name: 'Duplicate')
    ProductVariant.create!(product: @target, name: 'Duplicate', discontinued: false)

    assert_raises(ProductConversionService::ConversionError) do
      ProductConversionService.to_variant(@product.reload, @target)
    end

    assert Product.exists?(@product.id)
  end

  test 'converts a variant into a standalone product' do
    variant = product_variants(:one)
    parent = variant.product

    product = ProductConversionService.to_product(
      variant,
      sub_category_ids: parent.sub_category_ids
    )

    assert_equal 'LTD 2024', product.name
    assert_equal parent.brand_id, product.brand_id # inherited, never chosen
    assert_equal parent.sub_category_ids.sort, product.sub_category_ids.sort
    assert_nil ProductVariant.find_by(id: variant.id)
  end

  test 'moves the variant dependents onto the new product' do
    variant = product_variants(:one)
    parent = variant.product
    possession = possessions(:current_product_variant)
    bookmark = bookmarks(:with_product_variant)
    note = Note.create!(user: @user, product: parent, product_variant: variant, text: 'nice')
    option = ProductOption.create!(product_variant: variant, option: 'Walnut')

    product = ProductConversionService.to_product(
      variant,
      sub_category_ids: parent.sub_category_ids
    )

    assert_equal [product.id, nil], possession.reload.slice(:product_id, :product_variant_id).values
    assert_equal [product.id, nil], note.reload.slice(:product_id, :product_variant_id).values
    assert_equal [product.id, nil], option.reload.slice(:product_id, :product_variant_id).values
    assert_equal ['Product', product.id], bookmark.reload.slice(:item_type, :item_id).values
  end

  test 'only copies custom attributes when they are passed in' do
    variant = product_variants(:one)
    parent = variant.product
    specs = { 'impedance' => '300' }

    product = ProductConversionService.to_product(
      variant,
      sub_category_ids: parent.sub_category_ids,
      custom_attributes: specs
    )

    assert_equal specs, product.custom_attributes
  end

  test 'refuses to convert a nameless variant into a product' do
    variant = ProductVariant.create!(product: @target, name: '', release_year: 2001, discontinued: false)

    error = assert_raises(ProductConversionService::ConversionError) do
      ProductConversionService.to_product(
        variant,
        sub_category_ids: @target.sub_category_ids
      )
    end

    assert_match(/Name/, error.message)
    assert ProductVariant.exists?(variant.id)
  end

  test 'refuses to convert a variant without sub categories' do
    variant = product_variants(:one)

    assert_raises(ProductConversionService::ConversionError) do
      ProductConversionService.to_product(variant, sub_category_ids: [])
    end

    assert ProductVariant.exists?(variant.id)
  end

  test 'round trips a product through a variant and back' do
    variant = ProductConversionService.to_variant(@product, @target)
    product = ProductConversionService.to_product(
      variant,
      sub_category_ids: @target.sub_category_ids
    )

    assert_equal 'Elise', product.name
    assert_predicate product.slug, :present?
  end
end
