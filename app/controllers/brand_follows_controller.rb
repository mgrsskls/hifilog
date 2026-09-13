# frozen_string_literal: true

class BrandFollowsController < ApplicationController
  SUGGESTION_LIMIT = 5

  before_action :authenticate_user!
  before_action :set_menu

  def index
    page_title(I18n.t('headings.followed_brands'))
    @active_dashboard_menu = :community
    @active_community_tab = :brands
    @following_count = current_user.user_follows.count
    @followers_count = current_user.follower_relationships.count
    @brands_count = current_user.brand_follows.count
    @brand_follows = current_user.brand_follows
                                 .includes(brand: { logo_attachment: :blob })
                                 .joins(:brand)
                                 .order(Arel.sql('LOWER(brands.name) ASC'))
                                 .to_a
    @suggested_brands = suggested_brands if @brand_follows.empty?
  end

  # Brands are public, so -- unlike a user follow -- a missing or invalid target is nothing to
  # be coy about: there is no hidden brand to enumerate and no block to disclose.
  def create
    brand = Brand.find_by(id: params[:brand_id])
    if brand.nil?
      flash[:alert] = I18n.t(:generic_error_message)
      redirect_to dashboard_root_path and return
    end

    follow = current_user.brand_follows.new(brand:)

    if save_brand_follow(follow) || current_user.following_brand?(brand)
      flash[:notice] = I18n.t('brand_follow.messages.followed', name: brand.display_name)
    else
      flash[:alert] = I18n.t(:generic_error_message)
    end

    redirect_to redirect_path(brand)
  end

  def destroy
    follow = current_user.brand_follows.find_by(id: params[:id])

    unless follow
      flash[:alert] = I18n.t(:generic_error_message)
      redirect_to dashboard_root_path and return
    end

    brand = follow.brand
    follow.destroy

    flash[:notice] = I18n.t('brand_follow.messages.unfollowed', name: brand.display_name)
    redirect_to redirect_path(brand)
  end

  private

  # The uniqueness validation isn't atomic, so a race between two submissions of the same follow
  # can still hit the DB's unique index; that raises rather than failing validation.
  def save_brand_follow(follow)
    follow.save
  rescue ActiveRecord::RecordNotUnique
    false
  end

  def set_menu
    @active_menu = :dashboard
  end

  # A user who follows nothing yet is shown the brands they already collect. Without it the
  # feature is discovered only by people who happen to open a brand page.
  def suggested_brands
    Brand.joins(products: :possessions)
         .where(possessions: { user_id: current_user.id })
         .group('brands.id')
         .order(Arel.sql('COUNT(possessions.id) DESC, LOWER(brands.name) ASC'))
         .limit(SUGGESTION_LIMIT)
  end

  def redirect_path(brand)
    # url_from rejects external hosts, so a crafted redirect_to param falls back to the brand
    # page instead of raising UnsafeRedirectError.
    url_from(params[:redirect_to]) || brand_path(id: brand.friendly_id)
  end
end
