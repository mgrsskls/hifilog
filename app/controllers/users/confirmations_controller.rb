class Users::ConfirmationsController < Devise::ConfirmationsController
  skip_after_action :record_page_view

  private

  def after_confirmation_path_for(_, resource)
    sign_in(resource)
    dashboard_root_path
  end
end
