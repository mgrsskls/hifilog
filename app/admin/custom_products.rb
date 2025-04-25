ActiveAdmin.register CustomProduct do
  permit_params :name, :description, :user_id

  config.filters = false

  index do
    selectable_column
    id_column
    column :name
    column :description
    column :user
    column "Created", sortable: :created_at do |entity|
      "#{entity.created_at.strftime("%m.%d.%Y")}<br><small>#{entity.created_at.strftime("%H:%M")}</small>".html_safe
    end
    column "Updated", sortable: :updated_at do |entity|
      "#{entity.updated_at.strftime("%m.%d.%Y")}<br><small>#{entity.updated_at.strftime("%H:%M")}</small>".html_safe
    end
    actions
  end
end
