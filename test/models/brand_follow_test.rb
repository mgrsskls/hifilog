# frozen_string_literal: true

require 'test_helper'

class BrandFollowTest < ActiveSupport::TestCase
  test 'valid follow' do
    follow = BrandFollow.new(user: users(:visible), brand: brands(:one))
    assert follow.valid?
  end

  test 'unique per user and brand' do
    existing = brand_follows(:one_follows_feliks)
    duplicate = BrandFollow.new(user: existing.user, brand: existing.brand)

    assert_not duplicate.valid?
  end

  test 'a user can follow more than one brand' do
    user = users(:one)
    follow = BrandFollow.new(user:, brand: brands(:two))

    assert follow.valid?
  end

  # The test environment runs a null store, so the cache is swapped out here rather than written
  # to (Rails.cache is restored in the ensure block).
  test 'creating and destroying a follow flushes both audience counts' do
    brand = brands(:two)
    public_key = Brand.followers_count_cache_key(brand.id, nil)
    member_key = Brand.followers_count_cache_key(brand.id, true)
    store = ActiveSupport::Cache::MemoryStore.new
    original_cache = Rails.cache
    Rails.cache = store

    store.write(public_key, 99)
    store.write(member_key, 99)

    follow = BrandFollow.create!(user: users(:visible), brand:)

    assert_nil store.read(public_key)
    assert_nil store.read(member_key)

    store.write(public_key, 99)
    store.write(member_key, 99)
    follow.destroy

    assert_nil store.read(public_key)
    assert_nil store.read(member_key)
  ensure
    Rails.cache = original_cache
  end

  test 'destroying the user removes the follow' do
    user = users(:visible)
    BrandFollow.create!(user:, brand: brands(:two))

    assert_difference 'BrandFollow.count', -1 do
      user.destroy
    end
  end
end
