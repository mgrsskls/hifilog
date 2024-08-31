ActiveAdmin.register User do

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :email, :encrypted_password, :reset_password_token, :reset_password_sent_at, :remember_created_at, :random_username, :user_name, :unconfirmed_email

  remove_filter :reset_password_token
  remove_filter :profile_visibility
  remove_filter :confirmation_token
  remove_filter :unconfirmed_email
  remove_filter :possessions
  remove_filter :products
  remove_filter :product_variants
  remove_filter :setups
  remove_filter :setup_possessions
  remove_filter :bookmarks
  remove_filter :custom_products
  remove_filter :notes
  remove_filter :app_news
  remove_filter :avatar_attachment
  remove_filter :avatar_blob
  remove_filter :decorative_image_attachment
  remove_filter :decorative_image_blob
  remove_filter :email
  #
  # or
  #
  # permit_params do
  #   permitted = [:email, :encrypted_password, :reset_password_token, :reset_password_sent_at, :remember_created_at]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

end
