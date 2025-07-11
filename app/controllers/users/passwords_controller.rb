# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  skip_after_action :record_page_view

  # GET /resource/password/new
  def new
    @page_title = I18n.t('user_form.forgot_password.heading')
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
