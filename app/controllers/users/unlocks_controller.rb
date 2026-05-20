# frozen_string_literal: true

class Users::UnlocksController < Devise::UnlocksController
  skip_after_action :record_page_view

  # GET /resource/unlock/new
  # def new
  #   super
  # end

  # POST /resource/unlock
  def create
    return head :forbidden if request.is_crawler?

    if valid_turnstile?
      super
    else
      redirect_to new_user_unlock_path, alert: t('user_form.turnstile_failed')
    end
  end

  # GET /resource/unlock?unlock_token=abcdef
  # def show
  #   super
  # end

  # protected

  # The path used after sending unlock password instructions
  # def after_sending_unlock_instructions_path_for(resource)
  #   super(resource)
  # end

  # The path used after unlocking the resource
  # def after_unlock_path_for(resource)
  #   super(resource)
  # end
end
