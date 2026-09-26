# frozen_string_literal: true

class AppNewsController < ApplicationController
  before_action :authenticate_user!
  skip_after_action :record_page_view

  # permit keeps ids only as a list of values, so a missing or malformed ids marks nothing and the
  # request redirects like a normal click. News the user has read already is skipped:
  # app_news_users has a unique index, so a second click (for example from an older tab) would raise.
  def mark_as_read
    ids = params.permit(ids: []).fetch(:ids, [])
    unread = AppNews.where(id: ids).where.not(id: current_user.app_news_ids)
    current_user.app_news << unread.to_a

    flash[:notice] = I18n.t(:generic_error_message) unless current_user.save

    redirect_back_or_to dashboard_root_path
  end
end
