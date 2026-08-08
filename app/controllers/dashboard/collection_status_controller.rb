# frozen_string_literal: true

class Dashboard::CollectionStatusController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: CollectionStatusQuery.new(
      user: current_user,
      brand_ids: params[:brands],
      product_ids: params[:products],
      product_variant_ids: params[:product_variants],
      event_ids: params[:events]
    ).call
  end

  def counts
    render json: {
      products: user_possessions_count(user: current_user, prev_owned: false),
      custom_products: user_custom_products_count(current_user),
      previous_products: user_possessions_count(user: current_user, prev_owned: true),
      setups: user_setups_count(current_user),
      bookmarks: user_bookmarks_count(current_user),
      events: user_events_count(current_user),
      notes: user_notes_count(current_user)
    }
  end
end
