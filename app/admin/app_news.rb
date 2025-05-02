ActiveAdmin.register AppNews do
  permit_params :text

  config.filters = false

  menu parent: "HiFi Log"

  index do
    selectable_column
    id_column
    column :text
    column "Created", sortable: :created_at do |entity|
      "#{entity.created_at&.strftime("%m.%d.%Y")}<br><small>#{entity.created_at&.strftime("%H:%M")}</small>".html_safe
    end
    column "Updated", sortable: :updated_at do |entity|
      "#{entity.updated_at.strftime("%m.%d.%Y")}<br><small>#{entity.updated_at.strftime("%H:%M")}</small>".html_safe
    end
    column "Read by" do |app_news|
      app_news.users.count
    end
  end
end
