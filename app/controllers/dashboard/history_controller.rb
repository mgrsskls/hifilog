# frozen_string_literal: true

class Dashboard::HistoryController < ApplicationController
  include HistoryHelper

  before_action :authenticate_user!
  before_action :set_menu

  def index
    page_title(I18n.t('headings.history'))
    @active_dashboard_menu = :history
    @possessions = get_history_possessions(current_user.possessions)
  end

  private

  def set_menu
    @active_menu = :dashboard
  end
end
