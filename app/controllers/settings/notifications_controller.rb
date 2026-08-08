# frozen_string_literal: true

# Dashboard "Settings → Notifications" page: follow-notification and
# newsletter opt-in for the signed-in user. RESTful show/update on the
# current user's own notification preferences.
class Settings::NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_page_context

  def show; end

  def update
    if current_user.update(notification_settings_params)
      redirect_to dashboard_notification_settings_path, notice: t('user.notification_settings.updated')
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_page_context
    @active_menu = :dashboard
    @active_dashboard_menu = :notifications
    @user = current_user
    page_title(I18n.t('headings.notifications'))
  end

  def notification_settings_params
    params.expect(user: [:receives_follow_notifications, :receives_newsletter])
  end
end
