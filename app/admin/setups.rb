ActiveAdmin.register Setup do
  permit_params :name, :user_id, :private

  remove_filter :setup_possessions
  remove_filter :possessions
  remove_filter :name
  remove_filter :private

  index do
    id_column
    column :name
    column :created_at
    column :updated_at
    column :visibility
    column :user do |bookmark|
      link_to bookmark.user.email, admin_user_path(bookmark.user)
    end
    column :products do |setup|
      setup.possessions.count
    end
    actions
  end
end
