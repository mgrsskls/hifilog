class AppNewsController < ApplicationController
  before_action :authenticate_user!
  skip_after_action :record_page_view

  def mark_as_read
    params[:ids].each do |id|
      news = AppNews.find(id.to_i)
      current_user.app_news << news
    end

    flash[:notice] = I18n.t(:generic_error_message) unless current_user.save

    redirect_back_or_to dashboard_root_path
  end
end
