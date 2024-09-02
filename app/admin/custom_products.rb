ActiveAdmin.register CustomProduct do
  permit_params :name, :description, :user_id

  remove_filter :image_attachment
  remove_filter :image_blob
  remove_filter :possession
  remove_filter :sub_categories
end
