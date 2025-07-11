# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # before_action :configure_sign_in_params, only: [:create]
  skip_after_action :record_page_view

  # GET /resource/sign_in
  def new
    @active_menu = :login
    @page_title = I18n.t('user_form.login')
    super
  end

  # POST /resource/sign_in
  def create
    @active_menu = :login
    super
  end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
