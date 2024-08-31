class AppNewsController < ApplicationController
  before_action :authenticate_user!

  def mark_as_read
    params[:ids].each do |id|
      news = AppNews.find(id.to_i)
      current_user.app_news << news
    end

    current_user.save!

    redirect_back fallback_location: dashboard_root_path
  end
end
