ActiveAdmin.register AdminUser do
  permit_params :email, :password, :password_confirmation

  config.filters = false

  menu parent: "Settings"

  index do
    selectable_column
    id_column
    column :email
    column :current_sign_in_at
    column :sign_in_count
    column "Created", sortable: :created_at do |user|
      "#{user.created_at.strftime("%d.%m.%Y")}<br><small>#{user.created_at.strftime("%H:%M")}</small>".html_safe
    end
    actions
  end

  form do |f|
    f.inputs do
      f.input :email
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end

end
