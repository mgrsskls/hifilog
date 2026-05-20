# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  skip_after_action :record_page_view

  # POST /resource/confirmation
  def create
    return head :forbidden if request.is_crawler?

    if valid_turnstile?
      super
    else
      redirect_to new_user_confirmation_path, alert: t('user_form.turnstile_failed')
    end
  end

  private

  def after_confirmation_path_for(_, resource)
    sign_in(resource)
    dashboard_root_path
  end
end
