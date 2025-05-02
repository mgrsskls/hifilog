ActiveAdmin.register Category do
  permit_params :name, :slug, :order, :column

  config.filters = false

  menu parent: "Settings"

  action_item :add_sub_category, only: :show do
    link_to 'Add Sub Category', new_admin_sub_category_path(sub_category: { category_id: @category.id }), class: 'action-item-button'
  end

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end
  end
end
