ActiveAdmin.register SubCategory do

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :name, :category_id, :slug, custom_attribute_ids: []
  #
  # or
  #
  # permit_params do
  #   permitted = [:name, :category_id]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  form do |f|
    f.inputs do
      f.input :name
      f.input :slug
      f.input :category_id, label: "Category", as: :radio, collection: Category.all
      f.input :custom_attribute_ids, as: :check_boxes, collection: CustomAttribute.all, member_label: :options
    end
    f.submit
  end

  show do
    attributes_table do
      row :name
      row :category
      row :slug
      row :custom_attributes do |sub_category|
        sub_category.custom_attributes
      end
    end

    active_admin_comments_for(resource)
  end

  index do
    column :id
    column ("Name") do |c|
      SubCategory.find(c.id)
    end
    column :category
    column :slug
    column :custom_attributes
    actions
  end

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end
  end
end
