ActiveAdmin.register Category do
  permit_params :name, :slug, :order

  remove_filter :order
  remove_filter :slug
  remove_filter :sub_categories

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end
  end
end
