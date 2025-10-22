ActiveAdmin.register Newsletter do
  permit_params :content, :test_email, :test_user_name

  menu parent: "HiFi Log"

  config.filters = false

  member_action :send_test, method: [:get, :post] do
    if request.post?
      email = params[:test_email]
      user_name = params[:test_user_name]
      if email.present? && user_name.present?
        resource.send_test(email, user_name)
        redirect_to resource_path, notice: "Test newsletter sent to #{email}."
      else
        redirect_to resource_path, alert: "Please provide an email address."
      end
    else
      render 'active_admin/newsletters/send_test'  # render a custom form view
    end
  end

  member_action :send_newsletter, method: :post do
    resource.send_to_all
    redirect_to resource_path, notice: "Newsletter sent to all recipients!"
  end

  action_item :send_test, only: :show do
    link_to 'Send Test', send_test_admin_newsletter_path(resource), method: :get, class: 'action-item-button'
  end

  action_item :send_newsletter, only: :show do
    link_to 'Send Newsletter', send_newsletter_admin_newsletter_path(resource), method: :post, class: 'action-item-button'
  end
end
