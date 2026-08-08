# frozen_string_literal: true

class Dashboard::FeedController < ApplicationController
  FEED_PAGE_SIZE = 50

  before_action :authenticate_user!
  before_action :set_menu

  def index
    page_title(I18n.t('headings.feed'))
    @active_dashboard_menu = :feed

    feed_page = UserActivityTimeline.paginated_for_following(
      current_user, time_zone: Time.zone, page: params[:page], per: FEED_PAGE_SIZE
    )
    @feed = feed_page.rows
    @feed_pagination = feed_page.activities
  end

  private

  def set_menu
    @active_menu = :dashboard
  end
end
