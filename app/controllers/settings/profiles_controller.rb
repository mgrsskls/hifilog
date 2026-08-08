# frozen_string_literal: true

# Dashboard "Settings → Profile" page: profile visibility, avatar, and
# decorative image for the signed-in user. RESTful show/update on the
# current user's own profile settings.
class Settings::ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_page_context

  def show; end

  def update
    unless current_user.update_with_password(profile_settings_params)
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_content
      return
    end

    current_user.purge_avatar! if params[:delete_avatar]
    current_user.purge_decorative_image! if params[:delete_decorative_image]

    redirect_to dashboard_profile_settings_path, notice: t('user.profile_settings.updated')
  end

  private

  def set_page_context
    @active_menu = :dashboard
    @active_dashboard_menu = :profile
    @user = current_user
    page_title(I18n.t('headings.profile'))
  end

  def profile_settings_params
    params.expect(user: [:profile_visibility, :avatar, :decorative_image, :current_password])
  end
end
