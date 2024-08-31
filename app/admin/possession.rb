ActiveAdmin.register Possession do

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :name, :discontinued, :slug, :website, :country_code, :full_name
  #
  # or
  #
  # permit_params do
  #   permitted = [:name, :discontinued, :slug]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  remove_filter :custom_product
  remove_filter :image_attachment
  remove_filter :image_blob
  remove_filter :prev_owned
  remove_filter :product
  remove_filter :product_option
  remove_filter :product_variant
  remove_filter :setup
  remove_filter :setup_possession
end
