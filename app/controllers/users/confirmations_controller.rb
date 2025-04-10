class Users::ConfirmationsController < Devise::ConfirmationsController
  private

  def after_confirmation_path_for(_, resource)
    sign_in(resource)
    dashboard_root_path
  end
end
