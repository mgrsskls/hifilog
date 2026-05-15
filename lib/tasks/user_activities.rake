# frozen_string_literal: true

namespace :user_activities do
  desc 'Backfill user_activities from existing possessions, setups, setup memberships, custom products, and event RSVPs'
  task backfill: :environment do
    UserActivities::Backfill.run_all
  end
end
