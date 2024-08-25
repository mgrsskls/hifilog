# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # before_action :configure_sign_up_params, only: [:create]

  # GET /resource/sign_up
  def new
    @active_menu = :signup
    @page_title = I18n.t('user_form.signup')
    super
  end

  # POST /resource
  def create
    @active_menu = :signup
    super
  end

  # GET /resource/edit
  def edit
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
    add_breadcrumb I18n.t('account'), :edit_user_registration_path
    @page_title = I18n.t('account')
    @active_dashboard_menu = :account

    super
  end

  # PUT /resource
  def update
    add_breadcrumb I18n.t('your_profile')
    add_breadcrumb I18n.t('account')
    @active_dashboard_menu = :account

    current_user.avatar.purge if params[:delete_avatar]
    current_user.decorative_image.purge if params[:delete_decorative_image]

    # validation should not happen in controller, but see  explanation at try_create_and_upload_blob!
    uploaded_avatar = params.require(:user).fetch(:avatar, nil)
    if uploaded_avatar
      upload = try_create_and_upload_blob!(uploaded_avatar)

      if upload[:success]
        # byte_size is only available after upload
        if upload[:attachment].byte_size < 5_000_000
          current_user.avatar = upload[:attachment]
          params[:user].delete :avatar
        else
          current_user.errors.add(:avatar, 'is too big. Please use a file with a maximum of 5 MB.')
          upload[:attachment].purge
        end
      elsif upload[:error].present?
        current_user.errors.add(:avatar, upload[:error])
      end
    end

    # validation should not happen in controller, but see  explanation at try_create_and_upload_blob!
    uploaded_decorative_image = params.require(:user).fetch(:decorative_image, nil)
    if uploaded_decorative_image
      upload = try_create_and_upload_blob!(uploaded_decorative_image)

      if upload[:success]
        # byte_size is only available after upload
        if upload[:attachment].byte_size < 5_000_000
          current_user.decorative_image = upload[:attachment]
          params[:user].delete :decorative_image
        else
          current_user.errors.add(:decorative_image, 'is too big. Please use a file with a maximum of 5 MB.')
          upload[:attachment].purge
        end
      elsif upload[:error].present?
        current_user.errors.add(:decorative_image, upload[:error])
      end
    end

    if current_user.errors.any? || !current_user.save
      current_user.user_name = account_update_params[:user_name] if account_update_params[:user_name].present?
      current_user.email = account_update_params[:email] if account_update_params[:email].present?
      if account_update_params[:profile_visibility].present?
        current_user.profile_visibility = account_update_params[:profile_visibility]
      end
      render :edit, status: :unprocessable_entity
      return
    end

    super
  end

  def destroy
    Bookmark.where(user_id: current_user.id).find_each(&:destroy!)

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
