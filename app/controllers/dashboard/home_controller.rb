# frozen_string_literal: true

class Dashboard::HomeController < ApplicationController
  include CurrentStatisticsOverview

  before_action :authenticate_user!
  before_action :set_menu

  def show
    page_title(I18n.t('dashboard'))
    @active_dashboard_menu = :dashboard

    @feed = UserActivityTimeline.grouped_for_following(current_user, time_zone: Time.zone, limit: 10)

    @newest_users = newest_users

    load_current_statistics_summary

    @events = current_user.events.upcoming.order(start_date: :asc).limit(2).to_a
    @event_attendee_counts = EventAttendee.counts_for(@events.map(&:id))

    @app_news = AppNews.where('created_at > ?', current_user.created_at)
                       .where.not(id: current_user.app_news_ids)
                       .order(:created_at)
                       .reverse
  end

  private

  def set_menu
    @active_menu = :dashboard
  end
end
