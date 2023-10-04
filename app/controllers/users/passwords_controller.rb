# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("user_form.login"), :new_user_session_path

  # GET /resource/password/new
  def new
    add_breadcrumb I18n.t("user_form.forgot_password.heading")

    @active_menu = :login
    super
  end

  # POST /resource/password
  # def create
  #   super
  # end

  # GET /resource/password/edit?reset_password_token=abcdef
  # def edit
  #   super
  # end

  # PUT /resource/password
  # def update
  #   super
  # end

  # protected

  # def after_resetting_password_path_for(resource)
  #   super(resource)
  # end

  # The path used after sending reset password instructions
  # def after_sending_reset_password_instructions_path_for(resource_name)
  #   super(resource_name)
  # end
end
