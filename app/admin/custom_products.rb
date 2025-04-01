ActiveAdmin.register CustomProduct do
  permit_params :name, :description, :user_id

  remove_filter :highlighted_image_id
  remove_filter :images_attachments
  remove_filter :images_blobs
  remove_filter :possession
  remove_filter :sub_categories
end
