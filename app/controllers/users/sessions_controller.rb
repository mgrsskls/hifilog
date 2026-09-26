# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # before_action :configure_sign_in_params, only: [:create]
  skip_after_action :record_page_view
  # Prepended, so it runs before every other callback: once Devise allows params authentication, any
  # callback that calls current_user signs the user in from the form. A failed challenge must stop
  # the request before that, so it neither checks the password nor counts toward the lockout
  # (docs/privacy-auth-security.md#3-security).
  prepend_before_action :require_turnstile, only: :create

  # GET /resource/sign_in
  def new
    @active_menu = :login
    page_title(I18n.t('user_form.login'))
    @safe_redirect = safe_redirect_path(params[:redirect])
    @meta_robots = 'noindex, follow' if @safe_redirect.present?
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

  private

  def require_turnstile
    return head :forbidden if request.is_crawler?
    return if valid_turnstile?

    redirect_to new_user_session_path(redirect: safe_redirect_path(params[:redirect])),
                alert: t('user_form.turnstile_failed')
  end
end
