ActiveAdmin.register AppNews do
  permit_params :text

  remove_filter :text
  remove_filter :users

  index do
    id_column
    column :text
    column :created_at
    column :updated_at
    column :marked_as_read do |app_news|
      app_news.users.count
    end
  end
end
