# frozen_string_literal: true

require 'test_helper'

# The admin dashboard shows the latest activities next to the statistics.
class AdminDashboardTest < ActionDispatch::IntegrationTest
  test 'shows activities and sign-ups in one table, newest first' do
    only_sign_up(users(:visible), at: 30.minutes.ago)
    users(:visible).update_columns(confirmed_at: nil) # rubocop:disable Rails/SkipsModelValidations
    PaperTrail::Version.create!(item: brands(:one), event: 'update', whodunnit: users(:one).id.to_s,
                                created_at: 1.hour.ago)
    UserActivity.create!(user: users(:one), subject: setups(:one), verb: 'setup_created',
                         occurred_at: 2.hours.ago, metadata: { 'display_name' => 'one' })

    sign_in admin_users(:admin_user)
    get admin_dashboard_path

    assert_response :success
    assert_select 'table', count: 1
    rows = css_select('td[data-column=activity]').map { |cell| cell.text.squish }

    assert_equal ['username3 signed up (not confirmed yet)',
                  "one_username updated the brand #{brands(:one).name}",
                  'one_username created the setup one'],
                 rows.first(3)
    assert_select "td[data-column=activity] a[href='#{admin_user_path(users(:visible))}']", text: 'username3'
    assert_select "a[href='#{admin_user_activities_path}']"
    assert_select "a[href='#{admin_paper_trail_versions_path}']"
    assert_select 'h3', text: /Brands\z/
  end

  test 'a confirmed sign-up has no note' do
    only_sign_up(users(:visible), at: 1.minute.ago)

    sign_in admin_users(:admin_user)
    get admin_dashboard_path

    assert_select 'td[data-column=activity]', text: 'username3 signed up'
  end

  private

  # Fixtures are all created now, which would put every user at the top of the table. Moves them
  # back a year, so only the given user signed up recently.
  def only_sign_up(user, at:)
    User.update_all(created_at: 1.year.ago) # rubocop:disable Rails/SkipsModelValidations
    user.update_columns(created_at: at) # rubocop:disable Rails/SkipsModelValidations
  end
end
