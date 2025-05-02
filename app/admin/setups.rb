ActiveAdmin.register Setup do
  permit_params :name, :user_id, :private

  remove_filter :setup_possessions
  remove_filter :possessions
  remove_filter :name
  remove_filter :private

  menu parent: "Users"

  index do
    selectable_column
    id_column
    column :name
    column :user
    column "Created", sortable: :created_at do |entity|
      "#{entity.created_at&.strftime("%m.%d.%Y")}<br><small>#{entity.created_at&.strftime("%H:%M")}</small>".html_safe
    end
    column "Updated", sortable: :updated_at do |entity|
      "#{entity.updated_at.strftime("%m.%d.%Y")}<br><small>#{entity.updated_at.strftime("%H:%M")}</small>".html_safe
    end
    column :visibility
    column :products do |setup|
      setup.possessions.count
    end
    actions
  end
end
