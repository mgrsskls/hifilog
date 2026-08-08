# frozen_string_literal: true

class UserBlocksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_menu

  def index
    page_title(I18n.t('headings.blocked'))
    @active_dashboard_menu = :blocked
    @user_blocks = current_user.user_blocks
                               .includes(blocked: { avatar_attachment: :blob })
                               .joins(:blocked)
                               .order(Arel.sql('LOWER(users.user_name) ASC'))
  end

  def create
    blocked = User.find_by(id: params[:blocked_id])
    if blocked.nil? || blocked == current_user
      flash[:alert] = I18n.t(:generic_error_message)
      redirect_to redirect_path and return
    end

    block = current_user.user_blocks.new(blocked:)
    if block.save
      flash[:notice] = I18n.t('user_follow.messages.blocked', name: blocked.user_name)
    else
      flash[:alert] = I18n.t(:generic_error_message)
    end

    redirect_to redirect_path
  end

  def destroy
    block = current_user.user_blocks.find(params[:id])
    blocked = block.blocked

    block.destroy
    flash[:notice] = I18n.t('user_follow.messages.unblocked', name: blocked.user_name)

    redirect_to destroy_redirect_path(blocked)
  end

  private

  def set_menu
    @active_menu = :dashboard
  end

  # url_from rejects external hosts, so a crafted redirect_to param falls back
  # to the default path instead of raising UnsafeRedirectError.
  def redirect_path
    url_from(params[:redirect_to]) || dashboard_followers_path
  end

  def destroy_redirect_path(_blocked)
    redirect_path
  end
end
