ActiveAdmin.register User do
  permit_params :email, :encrypted_password, :reset_password_token, :reset_password_sent_at, :remember_created_at, :random_username, :user_name, :unconfirmed_email, :receives_newsletter

  config.filters = false

  index do
    selectable_column
    id_column
    column :email
    column :user_name
    column "Created", sortable: :created_at do |user|
      "#{user.created_at.strftime("%d.%m.%Y")}<br><small>#{user.created_at.strftime("%H:%M")}</small>".html_safe
    end
    column "Confirmed" do |user|
      user.confirmed_at.present?
    end
    column :possessions do |user|
      user.possessions.count
    end
    column "Newsletter", sortable: :receives_newsletter do |user|
      user.receives_newsletter
    end
    column "Visibility", sortable: :profile_visibility do |user|
      if user.profile_visibility == "hidden"
        "<span class=\"status-tag\" title=\"#{user.profile_visibility}\">&cross;</span>".html_safe
      elsif user.profile_visibility == :logged_in_only
        "<span class=\"status-tag\" title=\"#{user.profile_visibility}\" style=\"background: none; border: 1px solid\">&cross;</span>".html_safe
      else
        "<span class=\"status-tag\" data-status=\"yes\" title=\"#{user.profile_visibility}\">&check;</span>".html_safe
      end
    end
    actions
  end
end
