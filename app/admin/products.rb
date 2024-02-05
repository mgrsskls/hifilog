ActiveAdmin.register Product do
  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :name, :brand_id, :discontinued, :slug, sub_category_ids: []
  #
  # or
  #
  # permit_params do
  #   permitted = [:name, :brand_id, :discontinued, :slug]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  form do |f|
    f.inputs do
      f.input :name
      f.input :brand
      f.input :discontinued
      f.input :slug
      f.input :sub_category_ids, label: "Subcategories", as: :check_boxes, collection: SubCategory.all
    end
    f.submit
  end

  show do
    attributes_table do
      row :name
      row :created_at
      row :updated_at
      row :brand
      row :discontinued
      row :slug
      row :sub_categories do |product|
        product.sub_categories
      end
    end

    active_admin_comments_for(resource)
  end

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end
  end
end
