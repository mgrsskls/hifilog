ActiveAdmin.register Category do

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :name, :slug, :order
  #
  # or
  #
  # permit_params do
  #   permitted = [:name, :slug]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  remove_filter :order
  remove_filter :slug
  remove_filter :sub_categories

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end
  end
end
