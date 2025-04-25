ActiveAdmin.register Category do
  permit_params :name, :slug, :order, :column

  config.filters = false

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end
  end
end
