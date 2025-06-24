# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # before_action :configure_sign_up_params, only: [:create]
  skip_after_action :record_page_view

  # GET /resource/sign_up
  def new
    @active_menu = :signup
    @page_title = I18n.t('user_form.signup')
    super
  end

  # GET /resource/edit
  def edit
    @page_title = I18n.t('headings.account')
    @active_dashboard_menu = :account

    super
  end

  # POST /resource
  def create
    @active_menu = :signup
    super
  end

  # PUT /resource
  def update
    @page_title = I18n.t('headings.account')
    @active_dashboard_menu = :account

    current_user.avatar.purge if params[:delete_avatar]
    current_user.decorative_image.purge if params[:delete_decorative_image]

    super
  end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  protected

  def after_update_path_for(_resource)
    edit_user_registration_path
  end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end
end
