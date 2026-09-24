# frozen_string_literal: true

require 'test_helper'

class AdminActivityPresentersTest < ActiveSupport::TestCase
  setup do
    controller = ApplicationController.new
    controller.request = ActionDispatch::TestRequest.create
    @view = controller.view_context
  end

  test 'user activity: collection add names the user and links the product' do
    possession = possessions(:current_product)
    activity = UserActivity.new(user: users(:one), subject: possession, verb: 'added_to_collection',
                                occurred_at: Time.current)

    html = AdminUserActivityPresenter.new(activity, @view).sentence

    assert_includes html, 'one_username'
    assert_includes html, 'added'
    assert_includes html, possession.product.display_name
    assert_includes html, "/admin/products/#{possession.product.to_param}"
    assert_includes html, 'to their collection'
  end

  test 'user activity: follow is told from the side of the follower' do
    follower = users(:visible)
    activity = UserActivity.new(
      user: users(:one), subject_type: 'UserFollow', subject_id: 0, verb: 'followed_by_user',
      occurred_at: Time.current,
      metadata: { 'follower_id' => follower.id, 'follower_user_name' => follower.user_name }
    )

    text = strip(AdminUserActivityPresenter.new(activity, @view).sentence)

    assert_equal "#{follower.user_name} started following one_username", text
  end

  test 'user activity: event attendance names the event and its dates' do
    attendee = event_attendees(:one)
    activity = UserActivity.new(user: attendee.user, subject: attendee, verb: 'event_attendance',
                                occurred_at: Time.current,
                                metadata: { 'event_start_date' => '2000-01-01', 'event_end_date' => '2000-01-02' })

    text = strip(AdminUserActivityPresenter.new(activity, @view).sentence)

    assert_equal "#{attendee.user.user_name} will attend Event 1 (01.01.2000 – 02.01.2000)", text
  end

  test 'user activity: preload loads the subjects of a page' do
    activity = UserActivity.create!(user: users(:one), subject: setups(:one), verb: 'setup_created',
                                    occurred_at: Time.current, metadata: { 'display_name' => 'one' })

    AdminUserActivityPresenter.preload(UserActivity.where(id: activity.id))

    assert_equal 'one_username created the setup one', strip(AdminUserActivityPresenter.new(activity, @view).sentence)
  end

  test 'version: sentence and readable changes, without technical attributes' do
    brand = brands(:one)
    version = PaperTrail::Version.create!(
      item: brand, event: 'update', whodunnit: users(:one).id.to_s,
      object_changes: PaperTrail::Serializers::YAML.dump(
        'name' => ['Feliks', 'Feliks Audio'],
        'slug' => %w[feliks feliks-audio],
        'discontinued' => [false, true],
        'description' => [nil, 'New text']
      )
    )

    context = AdminVersionActivityPresenter.preload(PaperTrail::Version.where(id: version.id))
    presenter = AdminVersionActivityPresenter.new(version, @view, context)

    assert_equal 'one_username updated the brand Feliks Audio', strip(presenter.sentence)

    changes = presenter.changes.to_h { |change| [change.label, [change.before, change.after]] }

    assert_equal ['Feliks', 'Feliks Audio'], changes['Brand name']
    assert_equal %w[No Yes], changes['Discontinued']
    assert_equal [nil, 'New text'], changes['Description']
    assert_equal 3, changes.size, 'slug must not be shown'
  end

  test 'version: foreign keys show names, a missing user shows System' do
    version = PaperTrail::Version.create!(
      item: products(:one), event: 'update',
      object_changes: PaperTrail::Serializers::YAML.dump('brand_id' => [brands(:two).id, brands(:one).id])
    )

    context = AdminVersionActivityPresenter.preload([version])
    presenter = AdminVersionActivityPresenter.new(version, @view, context)

    assert strip(presenter.sentence).start_with?('System updated the product')
    change = presenter.changes.first

    assert_equal [brands(:two).name, brands(:one).name], [change.before, change.after]
  end

  test 'version: custom attributes show one change per changed attribute' do
    version = PaperTrail::Version.create!(
      item: products(:one), event: 'update',
      object_changes: PaperTrail::Serializers::YAML.dump(
        'custom_attributes' => [{ 'a' => 1, 'b' => 2 }.to_json, { 'a' => 1, 'b' => 3 }.to_json]
      )
    )

    context = AdminVersionActivityPresenter.preload([version])
    changes = AdminVersionActivityPresenter.new(version, @view, context).changes

    assert_equal 1, changes.size
    assert_equal %w[2 3], [changes.first.before, changes.first.after]
  end

  private

  def strip(html)
    Nokogiri::HTML.fragment(html).text.squish
  end
end
