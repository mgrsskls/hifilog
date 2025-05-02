ActiveAdmin.register BookmarkList do
  config.filters = false

  menu parent: "Users"

  index do
    selectable_column
    id_column
    column :user
    column :name
    column "Created", sortable: :created_at do |entity|
      "#{entity.created_at&.strftime("%m.%d.%Y")}<br><small>#{entity.created_at&.strftime("%H:%M")}</small>".html_safe
    end
    column "Updated", sortable: :updated_at do |entity|
      "#{entity.updated_at.strftime("%m.%d.%Y")}<br><small>#{entity.updated_at.strftime("%H:%M")}</small>".html_safe
    end
    column :products do |bookmark_list|
      bookmark_list.bookmarks.count
    end
    actions
  end
end
