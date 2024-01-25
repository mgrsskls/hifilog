# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  add_breadcrumb I18n.t('user_form.login'), :new_user_session_path

  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  def new
    @active_menu = :login
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
