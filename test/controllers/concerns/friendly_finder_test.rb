# frozen_string_literal: true

require 'test_helper'

class FriendlyFinderTest < ActionDispatch::IntegrationTest
  setup do
    brand = brands(:one)
    @legacy_slug = "legacy-brand-#{SecureRandom.hex(4)}"
    FriendlyId::Slug.create!(
      slug: @legacy_slug,
      sluggable_type: 'Brand',
      sluggable_id: brand.id
    )
    @brand = brand
  end

  teardown do
    FriendlyId::Slug.where(slug: @legacy_slug).delete_all if @legacy_slug
  end

  test 'show redirects to canonical slug when an old friendly id slug is used' do
    get brand_path(@legacy_slug)
    assert_response :moved_permanently
    assert_redirected_to brand_path(@brand)
  end
end
