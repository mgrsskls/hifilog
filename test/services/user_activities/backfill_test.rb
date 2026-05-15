# frozen_string_literal: true

require 'test_helper'

class UserActivitiesBackfillTest < ActiveSupport::TestCase
  test 'run_all completes without error' do
    assert_nothing_raised { UserActivities::Backfill.run_all }
  end

  test 'run_all is safe to run twice' do
    UserActivities::Backfill.run_all
    first_count = UserActivity.count
    UserActivities::Backfill.run_all
    assert_equal first_count, UserActivity.count
  end

  test 'run_all creates setup_product_added from existing setup_possessions when missing' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 7, 1, 10, 0, 0)) do
      Setup.create!(user: user, name: 'Backfill setup', private: false)
    end
    possession = travel_to(Time.zone.local(2026, 7, 1, 11, 0, 0)) do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
    end
    SetupPossession.create!(setup: setup, possession: possession)

    UserActivity.where(
      user_id: user.id,
      subject: setup,
      verb: 'setup_product_added'
    ).where("metadata->>'possession_id' = ?", possession.id.to_s).delete_all

    assert_difference(-> { UserActivity.where(verb: 'setup_product_added', subject: setup).count }, 1) do
      UserActivities::Backfill.run_all
    end

    assert UserActivity.exists?(
      user_id: user.id,
      subject: setup,
      verb: 'setup_product_added'
    ), 'expected backfilled setup_product_added row'

    act = UserActivity.where(
      user_id: user.id,
      subject: setup,
      verb: 'setup_product_added'
    ).where("metadata->>'possession_id' = ?", possession.id.to_s).sole

    assert_equal possession.id.to_s, act.metadata['possession_id'].to_s
  end
end
