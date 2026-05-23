# frozen_string_literal: true

class PrivacyPolicyAcceptancesController < ApplicationController
  before_action :authenticate_user!
  skip_after_action :record_page_view

  def new
    return redirect_to after_privacy_policy_acceptance_path if current_user.privacy_policy_current?

    page_title(I18n.t('privacy_policy_overlay.heading'))
  end

  def create
    unless privacy_policy_accepted?
      redirect_to new_privacy_policy_acceptance_path, alert: t('privacy_policy_overlay.required')
      return
    end

    current_user.accept_privacy_policy!
    redirect_to after_privacy_policy_acceptance_path, notice: t('privacy_policy_overlay.accepted')
  end

  def destroy
    current_user.destroy!
    sign_out(:user)
    redirect_to root_path, notice: t('privacy_policy_overlay.account_deleted')
  end

  private

  def privacy_policy_accepted?
    ActiveModel::Type::Boolean.new.cast(params[:privacy_policy_accepted])
  end

  def after_privacy_policy_acceptance_path
    stored_location_for(:user) || dashboard_root_path
  end
end
