ActiveAdmin.register BookmarkList do
  index do
    id_column
    column :name
    column :user do |bookmark|
      link_to bookmark.user.email, admin_user_path(bookmark.user)
    end
    column :created_at
    column :updated_at
    column :products do |bookmark_list|
      bookmark_list.bookmarks.count
    end
    actions
  end
end
