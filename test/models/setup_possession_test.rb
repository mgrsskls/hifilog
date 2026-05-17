# frozen_string_literal: true

require 'test_helper'

class SetupPossessionTest < ActiveSupport::TestCase
  test 'possession must belong to setup user' do
    setup = setups(:one)
    other_possession = Possession.create!(user: users(:visible), product: products(:one), prev_owned: false)

    sp = SetupPossession.new(setup: setup, possession: other_possession)
    assert_not sp.valid?
    assert sp.errors[:possession].any?
  end

  test 'creating setup_possession records setup_product_added activity' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 6, 1, 10, 0, 0)) do
      Setup.create!(user: user, name: 'Activity setup', private: false)
    end
    possession = Possession.create!(user: user, product: products(:one), prev_owned: false)

    assert_difference(-> { UserActivity.where(verb: 'setup_product_added').count }, 1) do
      SetupPossession.create!(setup: setup, possession: possession)
    end

    act = UserActivity.find_by!(verb: 'setup_product_added', subject: setup)
    assert_equal possession.id, act.metadata['possession_id']
    assert_equal products(:one).id, act.metadata['product_id']
    assert_not act.metadata.key?('product_url'), 'product link should be derived at display time, not stored'
  end

  test 'destroying setup_possession records setup_product_removed activity' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 6, 2, 10, 0, 0)) do
      Setup.create!(user: user, name: 'Remove setup', private: false)
    end
    possession = Possession.create!(user: user, product: products(:two), prev_owned: false)
    sp = SetupPossession.create!(setup: setup, possession: possession)

    assert_difference(-> { UserActivity.where(verb: 'setup_product_removed').count }, 1) do
      sp.destroy!
    end
  end

  test 'moving possession between setups records remove then add' do
    user = users(:without_anything)
    setup_a = travel_to(Time.zone.local(2026, 6, 3, 8, 0, 0)) do
      Setup.create!(user: user, name: 'Setup A', private: false)
    end
    setup_b = travel_to(Time.zone.local(2026, 6, 3, 9, 0, 0)) do
      Setup.create!(user: user, name: 'Setup B', private: false)
    end
    possession = Possession.create!(user: user, product: products(:diy_kit), prev_owned: false)
    sp = SetupPossession.create!(setup: setup_a, possession: possession)

    assert_difference(-> { UserActivity.where(verb: 'setup_product_removed').count }, 1) do
      assert_difference(-> { UserActivity.where(verb: 'setup_product_added').count }, 1) do
        sp.update!(setup_id: setup_b.id)
      end
    end
  end
end
