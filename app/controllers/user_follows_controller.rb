# frozen_string_literal: true

class UserFollowsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_menu

  def index
    page_title(I18n.t('headings.following'))
    setup_community_section(active_tab: :following)
    @user_follows = current_user.user_follows
                                .includes(:followed)
                                .joins(:followed)
                                .order(Arel.sql('LOWER(users.user_name) ASC'))
  end

  def followers
    page_title(I18n.t('headings.followers'))
    setup_community_section(active_tab: :followers)
    @follower_relationships = current_user.follower_relationships
                                          .includes(follower: { avatar_attachment: :blob })
                                          .joins(:follower)
                                          .order(Arel.sql('LOWER(users.user_name) ASC'))
  end

  def create
    followed = User.find_by(id: params[:followed_id])
    # Hidden users must be indistinguishable from nonexistent ones so the
    # endpoint cannot be used to enumerate them.
    if followed.nil? || followed == current_user || followed.hidden?
      flash[:alert] = I18n.t(:generic_error_message)
      redirect_to dashboard_root_path and return
    end

    follow = current_user.user_follows.new(followed:)
    if follow.save
      flash[:notice] = I18n.t('user_follow.messages.followed', name: followed.user_name)
    else
      # Deliberately generic: a distinct message would disclose being blocked.
      flash[:alert] = I18n.t(:generic_error_message)
    end

    redirect_to redirect_path
  end

  def destroy
    follow = current_user.user_follows.find_by(id: params[:id]) ||
             current_user.follower_relationships.find_by(id: params[:id])

    unless follow
      flash[:alert] = I18n.t(:generic_error_message)
      redirect_to dashboard_root_path and return
    end

    other_user = follow.follower_id == current_user.id ? follow.followed : follow.follower
    removing_follower = follow.followed_id == current_user.id

    follow.destroy

    flash[:notice] =
      if removing_follower
        I18n.t('user_follow.messages.removed_follower', name: other_user.user_name)
      else
        I18n.t('user_follow.messages.unfollowed', name: other_user.user_name)
      end

    redirect_to destroy_redirect_path(other_user, removing_follower:)
  end

  private

  def set_menu
    @active_menu = :dashboard
  end

  def setup_community_section(active_tab:)
    @active_dashboard_menu = :community
    @active_community_tab = active_tab
    @following_count = current_user.user_follows.count
    @followers_count = current_user.follower_relationships.count
  end

  def redirect_path
    requested_redirect_path || followed_profile_path
  end

  def followed_profile_path
    followed = User.find_by(id: params[:followed_id])
    followed&.profile_path || dashboard_root_path
  end

  def destroy_redirect_path(other_user, removing_follower:)
    requested_redirect_path || (removing_follower ? dashboard_followers_path : other_user.profile_path)
  end

  # url_from rejects external hosts, so a crafted redirect_to param falls back
  # to the default path instead of raising UnsafeRedirectError.
  def requested_redirect_path
    url_from(params[:redirect_to])
  end
end
