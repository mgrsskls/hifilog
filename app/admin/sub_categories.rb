ActiveAdmin.register SubCategory do
  permit_params :name, :category_id, :slug, custom_attribute_ids: []

  remove_filter :brands
  remove_filter :custom_attributes
  remove_filter :custom_products
  remove_filter :products
  remove_filter :slug

  form do |f|
    f.inputs do
      f.input :name
      f.input :slug
      f.input :category_id, label: "Category", as: :radio, collection: Category.all
      f.input :custom_attribute_ids, label: "Custom attributes", as: :check_boxes, collection: CustomAttribute.all.map { |ca| [ca.label, ca.id] }
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
    column :custom_attributes do |sub_category|
      sub_category.custom_attributes.map do |custom_attribute|
        link_to t("custom_attribute_labels.#{custom_attribute.label}"), admin_custom_attribute_path(custom_attribute)
      end
    end
    column :products do |sub_category|
      sub_category.products.count
    end
    actions
  end

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end
  end
end
