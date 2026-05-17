# frozen_string_literal: true

require 'test_helper'

class SetupTest < ActiveSupport::TestCase
  test 'visibility' do
    assert_equal 'Public', setups(:one).visibility
    assert_equal 'Private', setups(:two).visibility
  end

  test 'name presence validation' do
    setup = Setup.new(user_id: users(:one).id)
    assert_not setup.valid?
    assert setup.errors[:name].any?
  end

  test 'name uniqueness per user' do
    user = users(:one)
    setup1 = setups(:one)
    setup2 = Setup.new(name: setup1.name, user_id: user.id, private: true)
    assert_not setup2.valid?
    assert setup2.errors[:name].any?
  end

  test 'name can be duplicate across users' do
    setup1 = setups(:one)
    setup2 = Setup.new(
      name: setup1.name,
      user_id: users(:hidden).id,
      private: true
    )
    assert setup2.valid?
  end

  test 'private inclusion validation' do
    setup = Setup.new(name: 'Test', user_id: users(:one).id, private: nil)
    assert_not setup.valid?
    assert setup.errors[:private].any?
  end

  test 'renaming preserves previous slug in history' do
    setup = setups(:one)
    user = setup.user
    old_slug = setup.slug

    setup.update!(name: 'Renamed setup title')

    setup.reload
    assert_equal 'renamed-setup-title', setup.slug
    assert FriendlyId::Slug.exists?(slug: old_slug, sluggable: setup)
    assert user.setups.friendly.find(old_slug)
  end

  test 'user presence validation' do
    setup = Setup.new(name: 'Test', private: true)
    assert_not setup.valid?
    assert setup.errors[:user].any?
  end
end
